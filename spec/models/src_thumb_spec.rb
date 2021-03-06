require 'rails_helper'

describe SrcThumb do
  it { should validate_presence_of :content_type }

  it { should validate_presence_of :height }

  it { should validate_presence_of :size }

  it { should validate_presence_of :width }

  it { should belong_to :src_image }

  context 'setting fields derived from the image' do
    subject(:src_thumb) do
      src_thumb = SrcThumb.new(FactoryGirl.attributes_for(:src_thumb))
      src_thumb.valid?
      src_thumb
    end

    specify { expect(src_thumb.content_type).to eq('image/png') }
    specify { expect(src_thumb.height).to eq(50) }
    specify { expect(src_thumb.width).to eq(460) }
    specify { expect(src_thumb.size).to eq(279) }
  end

  describe '#dimensions' do
    it 'returns widthxheight' do
      src_thumb = FactoryGirl.create(:src_thumb)
      expect(src_thumb.dimensions).to eq('460x50')
    end
  end

  describe '#image_external_body' do
    let(:client) do
      Aws::S3::Client.new(
        stub_responses: {
          get_object: { body: 'data' }
        }
      )
    end

    context 'when image_external_bucket is nil' do
      it 'returns nil' do
        src_thumb = FactoryGirl.create(:src_thumb, image_external_key: 'key1')
        expect(src_thumb.image_external_body(client)).to be_nil
      end
    end

    context 'when image_external_key is nil' do
      it 'returns nil' do
        src_thumb = FactoryGirl.create(
          :src_thumb, image_external_bucket: 'bucket1'
        )
        expect(src_thumb.image_external_body(client)).to be_nil
      end
    end

    context 'when image_external_bucket and image_external_key are not nil' do
      it 'returns an IO of the image body from the external object store' do
        src_thumb = FactoryGirl.create(
          :src_thumb,
          image_external_bucket: 'bucket1',
          image_external_key: 'key1'
        )
        expect(src_thumb.image_external_body(client).read).to eq('data')
      end
    end
  end

  describe '#move_image_external' do
    let(:client) do
      Aws::S3::Client.new(
        stub_responses: {
          put_object: 'Forbidden'
        }
      )
    end

    context 'when the image hash is not set' do
      it 'sets the image hash' do
        src_thumb = FactoryGirl.create(:src_thumb)
        expect do
          src_thumb.move_image_external('bucket1', client)
        end.to change { src_thumb.image_hash }.from(nil).to(
          '23d1e19330642839d2fd346ddda586f8c1c01d01aa57c45059d69072d7b6c162'
        )
      end
    end

    context 'when the image is already in the bucket' do
      it 'does not write the image to the bucket' do
        src_thumb = FactoryGirl.create(
          :src_thumb,
          image_hash: 'hash1',
          updated_at: Time.at(0)
        )
        expect do
          src_thumb.move_image_external('bucket1', client)
        end.to_not raise_error
        expect(src_thumb.image_external_bucket).to eq('bucket1')
        expect(src_thumb.image_external_key).to eq('hash1')
        expect(src_thumb.image).to be_nil
        expect(src_thumb.updated_at).to eq(Time.at(0))
      end
    end

    context 'when the image is not already in the bucket' do
      before { client.stub_responses(:head_object, 'Forbidden') }

      it 'writes the image to the bucket' do
        src_thumb = FactoryGirl.create(:src_thumb, image_hash: 'hash1')
        expect do
          src_thumb.move_image_external('bucket1', client)
        end.to raise_error(Aws::S3::Errors::Forbidden)
      end
    end
  end
end
