RSpec.describe Krane::Report::Element do

  describe '.build' do

    context 'with missing args' do

      subject { described_class.build }

      it 'raise an exception' do
        expect { subject }.to raise_exception(ArgumentError, "missing keywords: id, severity, group_title, info, data, writer")
      end

    end

    context 'with required args' do

      let(:id)          { 'some-id' }
      let(:severity)    { :warning }
      let(:group_title) { 'group-title' }
      let(:info)        { 'info' }
      let(:data)        { Set.new }
      let(:writer) do
        -> r do
          "#{r.some_key} #{r.other_key}"
        end
      end

      before do
        @res = subject.build(
          id: id, 
          severity: severity, 
          group_title: group_title, 
          info: info, 
          data: data, 
          writer: writer
        )
      end

      context 'with data present' do

        let(:data) do
          s = Set.new
          s << {some_key: 'hello', other_key: 'foo'}
          s << {some_key: 'hello', other_key: 'bar'}
        end

        it 'builds the report Element map representation with items present' do
          expect(@res).to include(
            id:          id,
            status:      severity,
            group_title: group_title,
            info:        info,
            items: [
              "hello foo",
              "hello bar"
            ]
          )
        end

      end

      context 'whith empty data' do

        it 'builds the report Element map representation with `:success` status and no items' do
          expect(@res).to include(
            id:          id,
            status:      :success,
            group_title: group_title,
            info:        info,
            items:       nil
          )
        end

      end

    end

  end

end
