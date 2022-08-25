class LinepayService
  def initialize(api)
    @api = api
    @nonce = SecureRandom.uuid
  end

  def perform(body)
    signature = get_signature(body)
    
    resp = Faraday.post("#{ENV['line_pay_endpoint']}#{@api}") do |req|
      req.headers['Content-Type'] = 'application/json'
      req.headers['X-LINE-ChannelId'] = ENV['line_pay_channel_id']
      req.headers['X-LINE-Authorization-Nonce'] = @nonce
      req.headers['X-LINE-Authorization'] = signature
      req.body = body.to_json
    end

    @result = JSON.parse(resp.body)
  end

  def success?
    @result['returnCode'] == "0000"
  end

  def payment_url
    @result['info']['paymentUrl']['web']
  end

  def order_id
    @result['info']['orderId']
  end

  def transaction_id
    @result['info']['transactionId']
  end

  def returnMessage
    @result['returnMessage']
  end

  private

  def get_signature(body)
    secrect = ENV['line_pay_channel_secret']
    message = "#{secrect}#{@api}#{body.to_json}#{@nonce}"
    hash = OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), secrect, message)
    signature = Base64.strict_encode64(hash)
    return signature
  end
end