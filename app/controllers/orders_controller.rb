class OrdersController < ApplicationController
  before_action :authenticate_user!

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
      secrect = ENV['line_pay_channel_secret']
      nonce = SecureRandom.uuid
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

      signature = get_signature(secrect, uri, body, nonce)

      resp = Faraday.post("#{ENV['line_pay_endpoint']}/v3/payments/request") do |req|
        req.headers['Content-Type'] = 'application/json'
        req.headers['X-LINE-ChannelId'] = ENV['line_pay_channel_id']
        req.headers['X-LINE-Authorization-Nonce'] = nonce
        req.headers['X-LINE-Authorization'] = signature
        req.body = body.to_json
      end

      result = JSON.parse(resp.body)

      if result['returnCode'] == "0000"
        payment_url = result['info']['paymentUrl']['web']
        redirect_to payment_url
      else
        redirect_to root_path, notice: '付款發生錯誤'
      end
      
    end
  end

  private
  def order_params
    params.require(:order).permit(:recipient, :tel, :address, :note)
  end

  def get_signature(secrect, uri, body, nonce)
    message = "#{secrect}#{uri}#{body.to_json}#{nonce}"
    hash = OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), secrect, message)
    signature = Base64.strict_encode64(hash)
    return signature
  end
end
