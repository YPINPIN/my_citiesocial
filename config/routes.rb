Rails.application.routes.draw do
  devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }
  root 'products#index'

  resources :products, only: [:index, :show]
  resources :categories, only: [:show] # /categories/2
  
  resource :cart, only: [:show, :destroy] do
    collection do
      # /cart/checkout
      get :checkout
    end
  end

  resources :orders, expect: [:new, :edit, :update, :destroy] do
    member do
      delete :cancel # /orders/8/cancel
      post :pay # /orders/8/pay
      get :pay_confirm  # /orders/8/pay_confirm
    end

    collection do
      get :confirm  # /orders/confirm
    end
  end

  namespace :admin do
    root 'products#index' # /admin
    resources :products
    resources :vendors, except: [:show]
    resources :categories, except: [:show] do
      collection do
        put :sort # PUT /admin/categories/sort
      end
    end
  end

  namespace :api do
    namespace :v1 do
      # POST /api/v1/subscribe
      post 'subscribe', to: 'utils#subscribe'
      # POST /api/v1/cart
      post 'cart', to: 'utils#cart'
    end
  end

end
