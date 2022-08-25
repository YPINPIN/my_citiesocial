class OrdersController < ApplicationController
  before_action :authenticate_user!

  def index
    @orders = current_user.orders.order(id: :desc)
  end

  def create
    @order = current_user.orders.build(order_params)

    products = []
    current_cart.items.each do |item|
      @order.order_items.build(sku_id: item.sku_id, quantity: item.quantity)
      products.push(
        {
          name: item.product.name,
          quantity: item.quantity,
          price: item.product.sell_price.to_i
        }
      )
    end

    if @order.save
      uri = '/v3/payments/request'
      body = {
        "amount": current_cart.total_price.to_i,
        "currency": "TWD",
        "orderId": @order.num,
        "packages": [
          {
            "id": @order.num,
            "amount": current_cart.total_price.to_i,
            "products": products
          }
        ],
        "redirectUrls": {
          "confirmUrl": "http://localhost:3000/orders/confirm",
          "cancelUrl": "http://localhost:3000/orders/cancel"
        }
      }

      resp = post_resp(uri, body)

      result = JSON.parse(resp.body)

      if result['returnCode'] == "0000"
        payment_url = result['info']['paymentUrl']['web']
        redirect_to payment_url
      else
        redirect_to root_path, notice: '付款發生錯誤'
      end
      
    end
  end

  def confirm
    uri = "/v3/payments/#{params[:transactionId]}/confirm"
    body = {
      "amount": current_cart.total_price.to_i,
      "currency": "TWD",
    }

    resp = post_resp(uri, body)

    result = JSON.parse(resp.body)

    if result['returnCode'] == "0000"
      order_id = result['info']['orderId']
      transaction_id = result['info']['transactionId']

      # 1. 變更 order狀態
      order = current_user.orders.find_by(num: order_id)
      order.pay!(transaction_id: transaction_id)

      # 2. 清空購物車
      session[:cart_9527] = nil

      redirect_to root_path, notice: '付款已完成'
    else
      redirect_to root_path, notice: "付款發生錯誤：#{result['returnMessage']}"
    end
  end

  private
  def order_params
    params.require(:order).permit(:recipient, :tel, :address, :note)
  end

  def get_signature(uri, body, nonce)
    secrect = ENV['line_pay_channel_secret']
    message = "#{secrect}#{uri}#{body.to_json}#{nonce}"
    hash = OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), secrect, message)
    signature = Base64.strict_encode64(hash)
    return signature
  end

  def post_resp(uri, body)
    nonce = SecureRandom.uuid
    signature = get_signature(uri, body, nonce)
    
    post_resp = Faraday.post("#{ENV['line_pay_endpoint']}#{uri}") do |req|
      req.headers['Content-Type'] = 'application/json'
      req.headers['X-LINE-ChannelId'] = ENV['line_pay_channel_id']
      req.headers['X-LINE-Authorization-Nonce'] = nonce
      req.headers['X-LINE-Authorization'] = signature
      req.body = body.to_json
    end
  end
end
