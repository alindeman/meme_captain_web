# Job to fetch and normalize source images and create thumbnails.
class SrcImageProcessJob < ActiveJob::Base
  queue_as do
    # rubocop:disable Style/RedundantSelf
    src_image = SrcImage.without_image.find(self.arguments.first)
    # rubocop:enable Style/RedundantSelf
    if src_image.url?
      :src_image_process_url
    else
      :src_image_process
    end
  end

  def perform(src_image_id)
    src_image = SrcImage.find(src_image_id)
    src_image.load_from_url

    img = src_image.magick_image_list

    img.auto_orient!
    img.strip!

    MemeCaptainWeb::ImgSizeConstrainer.new.constrain_size(img)

    thumb_img = img.resize_to_fill_anim(MemeCaptainWeb::Config::THUMB_SIDE)

    watermark(img)

    src_image.attributes = {
      image: img.to_blob,
      src_thumb: SrcThumb.new(image: thumb_img.to_blob),
      work_in_progress: false
    }

    img.destroy!

    src_image.set_derived_image_fields

    src_image.save!

    SrcImageNameJob.perform_later(src_image.id)
  end

  private

  def watermark(img)
    watermark_img = Magick::ImageList.new(
      Rails.root + 'app/assets/images/watermark.png')
    img.extend(MemeCaptain::ImageList::Watermark)
    img.watermark_mc(watermark_img)
    watermark_img.destroy!
  end
end
