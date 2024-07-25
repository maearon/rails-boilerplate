class Api::PostMediasController < Api::ApiController
  include Rails.application.routes.url_helpers

  before_action :authenticate!, except: %i[create]
  before_action :correct_user, only: :destroy

  def create
    attachment_ids = []
    if post_media_params[:files].present?
      post_media_params[:files].each do |index, file|
        media_type = determine_media_type(file)
        
        if media_type.nil?
          render json: { error: "Unsupported file type" }, status: :unprocessable_entity and return
        end

        post_media = PostMedia.new(media_type: media_type)
        post_media.id = SecureRandom.uuid

        if post_media.save
          post_media.file.attach(file)
          
          # Generate URL after attaching the file
          post_media.url = rails_blob_path(post_media.file, only_path: true)
          
          if post_media.save
            attachment_ids.push(post_media.id)
          else
            render json: { error: "Failed to update media URL", details: post_media.errors.full_messages }, status: :unprocessable_entity and return
          end
        else
          render json: { error: "Failed to save media", details: post_media.errors.full_messages }, status: :unprocessable_entity and return
        end
      end
    end

    if attachment_ids.any?
      render json: { flash: ["success", "PostMedia created!"], attachments: attachment_ids }
    else
      render json: { error: "No files were uploaded" }, status: :unprocessable_entity
    end
  end

  def destroy
    @post_media.destroy
    render json: { flash: ["success", "PostMedia deleted"] }
  end

  private

  def post_media_params
    params.require(:post_media).permit(files: {})
  end

  def determine_media_type(file)
    content_type = file.content_type.downcase
    extension = File.extname(file.original_filename).downcase

    image_types = %w[.jpg .jpeg .png .gif .bmp .webp .tiff .svg]
    video_types = %w[.mp4 .avi .mov .wmv .flv .webm .mkv .m4v]

    if content_type.start_with?('image/') || image_types.include?(extension)
      'image'
    elsif content_type.start_with?('video/') || video_types.include?(extension)
      'video'
    else
      nil # Unsupported file type
    end
  end

  def correct_user
    @post_media = current_user.post_medias.find_by(id: params[:id])
    if @post_media.nil?
      render json: { flash: ["error", "PostMedia with id = #{params[:id]} not found!"] }
    end
  end
end