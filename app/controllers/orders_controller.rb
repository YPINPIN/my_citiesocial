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

      linepay = LinepayService.new('/v3/payments/request')
      linepay.perform(body)

      if linepay.success?
        redirect_to linepay.payment_url
      else
        redirect_to root_path, notice: '付款發生錯誤'
      end
      
    end
  end

  def confirm
    body = {
      "amount": current_cart.total_price.to_i,
      "currency": "TWD",
    }

    linepay = LinepayService.new("/v3/payments/#{params[:transactionId]}/confirm")
    linepay.perform(body)

    if linepay.success?
      # 1. 變更 order狀態
      order = current_user.orders.find_by(num: linepay.order_id)
      order.pay!(transaction_id: linepay.transaction_id)

      # 2. 清空購物車
      session[:cart_9527] = nil

      redirect_to root_path, notice: '付款已完成'
    else
      redirect_to root_path, notice: "付款發生錯誤：#{linepay.returnMessage}"
    end
  end

  def cancel
    @order = current_user.orders.find(params[:id])

    if @order.paid?
      body = {}

      linepay = LinepayService.new("/v3/payments/#{@order.transaction_id}/refund")
      linepay.perform(body)

      if linepay.success?
        @order.cancel!
        redirect_to orders_path, notice: "訂單 #{@order.num} 已取消，並完成退款!"
      else
        redirect_to orders_path, notice: "退款發生錯誤：#{linepay.returnMessage}"
      end
    else
      @order.cancel!
      redirect_to orders_path, notice: "訂單 #{@order.num} 已取消!"
    end
  end

  def pay
    @order = current_user.orders.find(params[:id])

    products = []
    @order.order_items.each do |item|
      products.push(
        {
          name: item.product.name,
          quantity: item.quantity,
          price: item.product.sell_price.to_i
        }
      )
    end

    body = {
      "amount": @order.total_price.to_i,
      "currency": "TWD",
      "orderId": @order.num,
      "packages": [
        {
          "id": @order.num,
          "amount": @order.total_price.to_i,
          "products": products
        }
      ],
      "redirectUrls": {
        "confirmUrl": "http://localhost:3000/orders/#{@order.id}/pay_confirm",
        "cancelUrl": "http://localhost:3000/orders/#{@order.id}/pay_cancel"
      }
    }

    linepay = LinepayService.new('/v3/payments/request')
    linepay.perform(body)

    if linepay.success?
      redirect_to linepay.payment_url
    else
      redirect_to orders_path, notice: '付款發生錯誤'
    end
  end

  def pay_confirm
    @order = current_user.orders.find(params[:id])

    body = {
      "amount": @order.total_price.to_i,
      "currency": "TWD",
    }

    linepay = LinepayService.new("/v3/payments/#{params[:transactionId]}/confirm")
    linepay.perform(body)

    if linepay.success?
      @order.pay!(transaction_id: linepay.transaction_id)
      redirect_to orders_path, notice: '付款已完成'
    else
      redirect_to orders_path, notice: "付款發生錯誤：#{linepay.returnMessage}"
    end
  end

  private
  def order_params
    params.require(:order).permit(:recipient, :tel, :address, :note)
  end
end
