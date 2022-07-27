class Api::V1::UtilsController < ApplicationController
  def subscribe
    render json: { ststus: 'ok'}
  end
end
