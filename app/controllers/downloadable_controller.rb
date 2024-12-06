# frozen_string_literal: true

class DownloadableController < ApplicationController
  before_action :set_downloadable

  # メール送信しなければ動くコード
  def verify_password_post
    Rails.logger.info("Session download_password at downloadable_controller: #{session[:download_password]}")
    blob_id = params[:blob_id]
    entered_password = params[:password]

    if entered_password == session[:download_password]
      @document = ActiveStorage::Attachment.find_by(blob_id:)

      if @document
        file = @document.blob
        @download_url = rails_blob_url(file)
        # ファイルのダウンロードURLを提供するページをレンダリング
        render :download_page
      else
        Rails.logger.warn("No attachment found for blob ID: #{blob_id}")
        flash[:alert] = 'ファイルが見つかりませんでした。'
        render :verify_password
      end
    else
      if current_user.email == "yasuhiro-suzuki@mitsui-s.com"
        flash[:alert] = "無効なパスワードです。正しいパスワードは: #{session[:download_password]}"  # 正しいパスワードを表示
      else
        flash[:alert] = "無効なパスワードです。"  # 正しいパスワードを表示しない
      end
      render :verify_password and return  # returnを追加
    end
  end

  def new
    @user = User.find(session[:otp_user_id])
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = 'ユーザーが見つかりませんでした。'
    redirect_to root_path
    nil
  end

  def verify_password
    Rails.logger.info('verify_password action called')
    Rails.logger.debug { "params[:blob_id]: #{params[:blob_id]}" }
    Rails.logger.debug { "session[:download_blob_id]: #{session[:download_blob_id]}" }
    Rails.logger.debug { "Entered password: #{params[:password]}" }
    Rails.logger.debug { "Session password: #{session[:download_password]}" }
  
    # セッションパスワードが設定されているか確認
    if session[:download_password].blank?
      Rails.logger.warn("セッションパスワードが設定されていません。")
      
      # volumeフォルダからパスワードを読み込む
      begin
        session[:download_password] = File.read(Rails.root.join('volume', 'pass_word.txt')).strip
        Rails.logger.info("セッションパスワードをファイルから読み込みました。")
      rescue Errno::ENOENT
        Rails.logger.error("pass_word.txtファイルが見つかりません。")
        flash[:alert] = 'パスワードが設定されていません。'
        render :verify_password and return  # returnを追加
      end
      
      flash[:alert] = 'パスワードが設定されていません。'
      render :verify_password and return  # returnを追加
    end
  
    # パスワードが提供されていない場合、パスワード入力ページをレンダリング
    unless params[:password]
      @document = ActiveStorage::Attachment.find_by(blob_id: params[:blob_id])
      render :verify_password and return  # returnを追加
    end
  
    if params[:blob_id].present?
      session[:download_blob_id] = params[:blob_id]
      blob_id = session[:download_blob_id]
      Rails.logger.debug { "Blob ID: #{blob_id}" }
    else
      Rails.logger.warn("blob_id is missing in params.")
    end
  
    entered_password = params[:password]
  
    if entered_password == session[:download_password]
      @document = ActiveStorage::Attachment.find_by(blob_id: params[:blob_id])
  
      if @document
        file = @document.blob
        @download_url = rails_blob_url(file)
        render :download_page and return  # returnを追加
      else
        Rails.logger.warn("No attachment found for blob ID: #{blob_id}")
        flash[:alert] = 'ファイルが見つかりませんでした。'
        render :verify_password and return  # returnを追加
      end
    else
      if current_user.email == "yasuhiro-suzuki@mitsui-s.com"
        flash[:alert] = "無効なパスワードです。正しいパスワードは: #{session[:download_password]}"  # 正しいパスワードを表示
      else
        flash[:alert] = "無効なパスワードです。"  # 正しいパスワードを表示しない
      end
      render :verify_password and return  # returnを追加
    end
  end

  

  def download
    blob_id = session[:download_blob_id]
    file_attachment = ActiveStorage::Attachment.find_by(blob_id:)

    # エラーハンドリングを追加
    unless file_attachment
      Rails.logger.warn("No attachment found for blob ID: #{blob_id} during download action.")
      redirect_to root_path, alert: 'ダウンロードするファイルが見つかりませんでした。'
      return
    end

    file = file_attachment.blob
    send_data file.download, filename: file.filename.to_s, disposition: 'attachment'
  end

  private

  def set_downloadable
    model = if request.path.include?('/products/')
              Rails.logger.info('Model detected: Product')
              Product
            elsif request.path.include?('/suppliers/')
              Rails.logger.info('Model detected: Supplier')
              Supplier
            elsif request.path.include?('/touans/')
              Rails.logger.info('Model detected: Touan')
              Touan
            end

    if model
      @downloadable = model.find_by(id: params[:id])
      if @downloadable
        Rails.logger.info("Found #{@downloadable.class.name} with ID: #{params[:id]}")
      else
        Rails.logger.error("#{model.name} not found with ID: #{params[:id]}")
        redirect_to root_path, alert: 'リクエストが無効です。'
      end
    else
      Rails.logger.error("Unknown controller in path: #{request.path}")
      redirect_to root_path, alert: 'リクエストが無効です。'
    end
  end
end
