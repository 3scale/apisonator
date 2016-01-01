require_relative '../../script/redis/stats_keys_2_csv'

describe StatsKeys2CSV do
  let(:valid_input_lines) do
    ['"stats/{service:1006371740271}/cinstance:53f52e5a/'\
     'metric:2555417626402/year:20120102":"1"',
     '"stats/{service:1006371740188}/cinstance:37415b72/'\
     'metric:2555417571418/year:20120102":"59"']
  end

  let(:valid_input_lines_csv_conversions) do
    ['2012,01,02,,,year,1006371740271,53f52e5a,,2555417626402,,1',
     '2012,01,02,,,year,1006371740188,37415b72,,2555417571418,,59']
  end

  let(:line_with_missing_columns) { '"stats/metric:2555417626402":"1"' }

  describe '#to_csv!' do
    context 'when input includes only valid lines' do
      let(:stats_key_to_csv) do
        StatsKeys2CSV.new(input: StringIO.new(valid_input_lines.join("\n")),
                          output: StringIO.new,
                          error: StringIO.new)
      end

      before do
        stats_key_to_csv.to_csv!
      end

      it 'output contains the valid lines converted to CSV' do
        output_lines = stats_key_to_csv.output.string.split("\n")
        expect(output_lines).to match_array valid_input_lines_csv_conversions
      end

      it 'error is empty' do
        error_lines = stats_key_to_csv.error.string.split("\n")
        expect(error_lines).to be_empty
      end
    end

    context 'when input includes both valid and invalid lines' do
      let(:input_lines) do
        [valid_input_lines.first, line_with_missing_columns]
      end

      let(:stats_key_to_csv) do
        StatsKeys2CSV.new(input: StringIO.new(input_lines.join("\n")),
                          output: StringIO.new,
                          error: StringIO.new)
      end

      before do
        stats_key_to_csv.to_csv!
      end

      it 'output contains the valid lines converted to CSV' do
        output_lines = stats_key_to_csv.output.string.split("\n")
        expect(output_lines.count).to eq 1
        expect(output_lines.first).to eq valid_input_lines_csv_conversions.first
      end

      it 'error contains the invalid lines' do
        error_lines = stats_key_to_csv.error.string.split("\n")
        expect(error_lines.count).to eq 1
        expect(error_lines.first).to eq line_with_missing_columns
      end
    end

    context 'when input is a line with N/A' do
      let(:line_with_na) do
        '"stats/{service:1006371740271}/cinstance:53f52e5a/uinstance:N/A/'\
        'metric:2555417626402/year:20120102":"1"'
      end

      let(:stats_key_to_csv) do
        StatsKeys2CSV.new(input: StringIO.new(line_with_na),
                          output: StringIO.new,
                          error: StringIO.new)
      end

      before do
        stats_key_to_csv.to_csv!
      end

      it 'output contains a CSV where the key with N/A does not appear' do
        output_lines = stats_key_to_csv.output.string.split("\n")
        expect(output_lines.count).to eq 1
        expect(output_lines[0])
            .to eq '2012,01,02,,,year,1006371740271,53f52e5a,,2555417626402,,1'
      end

      it 'error is empty' do
        error_lines = stats_key_to_csv.error.string.split("\n")
        expect(error_lines).to be_empty
      end
    end

    context 'when input is a line with invalid period' do
      let(:line_with_invalid_period) do
        '"stats/{service:1006371740271}/cinstance:53f52e5a/metric:2555417626402/'\
        'invalid_period:20120102":"1"'
      end

      let(:stats_key_to_csv) do
        StatsKeys2CSV.new(input: StringIO.new(line_with_invalid_period),
                          output: StringIO.new,
                          error: StringIO.new)
      end

      before do
        stats_key_to_csv.to_csv!
      end

      it 'output is empty' do
        output_lines = stats_key_to_csv.output.string.split("\n")
        expect(output_lines).to be_empty
      end

      it 'error contains the line with the invalid period' do
        error_lines = stats_key_to_csv.error.string.split("\n")
        expect(error_lines.count).to eq 1
        expect(error_lines.first).to eq line_with_invalid_period
      end
    end

    context 'when input is a line without all the required columns' do
      let(:stats_key_to_csv) do
        StatsKeys2CSV.new(input: StringIO.new(line_with_missing_columns),
                          output: StringIO.new,
                          error: StringIO.new)
      end

      before do
        stats_key_to_csv.to_csv!
      end

      it 'output is empty' do
        output_lines = stats_key_to_csv.output.string.split("\n")
        expect(output_lines).to be_empty
      end

      it 'error contains the line without all the required columns' do
        error_lines = stats_key_to_csv.error.string.split("\n")
        expect(error_lines.count).to eq 1
        expect(error_lines.first).to eq line_with_missing_columns
      end
    end

    context 'when using the header option with a valid line in the input' do
      let(:input_line) { valid_input_lines.first }

      let(:stats_key_to_csv) do
        StatsKeys2CSV.new(input: StringIO.new(input_line),
                          output: StringIO.new,
                          error: StringIO.new,
                          header: true)
      end

      before do
        stats_key_to_csv.to_csv!
      end

      it 'output contains a header and the valid line converted to CSV' do
        output_lines = stats_key_to_csv.output.string.split("\n")
        expect(output_lines.count).to eq 2
        expect(output_lines[0]).to eq "# #{StatsKeys2CSV::ALL_COLUMNS.join(',')}"
        expect(output_lines[1]).to eq valid_input_lines_csv_conversions.first
      end

      it 'error is empty' do
        error_lines = stats_key_to_csv.error.string.split("\n")
        expect(error_lines).to be_empty
      end
    end

    context 'when using the with-keys option with a valid line in the input' do
      let(:input_line) { valid_input_lines.first }

      let(:stats_key_to_csv) do
        StatsKeys2CSV.new(input: StringIO.new(input_line),
                          output: StringIO.new,
                          error: StringIO.new,
                          keys: true)
      end

      before do
        stats_key_to_csv.to_csv!
      end

      it 'output contains the valid line converted to CSV with the original key commented' do
        output_lines = stats_key_to_csv.output.string.split("\n")
        expect(output_lines.count).to eq 1
        expect(output_lines[0])
            .to eq "#{valid_input_lines_csv_conversions.first} # #{input_line}"
      end

      it 'error is empty' do
        error_lines = stats_key_to_csv.error.string.split("\n")
        expect(error_lines).to be_empty
      end
    end

    context 'when using header and with-keys option together with a valid line in the input' do
      let(:input_line) { valid_input_lines.first }

      let(:stats_key_to_csv) do
        StatsKeys2CSV.new(input: StringIO.new(input_line),
                          output: StringIO.new,
                          error: StringIO.new,
                          header: true,
                          keys: true)
      end

      before do
        stats_key_to_csv.to_csv!
      end

      it 'the first line of output contains the headers' do
        first_line_output = stats_key_to_csv.output.string.split("\n").first
        expect(first_line_output)
            .to eq "# #{StatsKeys2CSV::ALL_COLUMNS.join(',')}"
      end

      it 'the 2nd line of output contains the conversion to CSV and the original key commented' do
        second_line_output = stats_key_to_csv.output.string.split("\n")[1]
        expect(second_line_output)
            .to eq "#{valid_input_lines_csv_conversions.first} # #{input_line}"
      end

      it 'error is empty' do
        error_lines = stats_key_to_csv.error.string.split("\n")
        expect(error_lines).to be_empty
      end
    end
  end

  context 'when the input contains N/A and an error' do
    let(:input_line) { '"stats/metric:N/A":"1"' }

    let(:stats_key_to_csv) do
      StatsKeys2CSV.new(input: StringIO.new(input_line),
                        output: StringIO.new,
                        error: StringIO.new)
    end

    before do
      stats_key_to_csv.to_csv!
    end

    it 'output is empty' do
      output_lines = stats_key_to_csv.output.string.split("\n")
      expect(output_lines).to be_empty
    end

    it 'error contains the line with N/A' do
      error_lines = stats_key_to_csv.error.string.split("\n")
      expect(error_lines.count).to eq 1
      expect(error_lines.first).to eq input_line
    end
  end

  describe '#errored?' do
    context 'when the input contains an error' do
      let(:stats_key_to_csv) do
        StatsKeys2CSV.new(input: StringIO.new(line_with_missing_columns),
                          output: StringIO.new,
                          error: StringIO.new)
      end

      before do
        stats_key_to_csv.to_csv!
      end

      it 'returns true' do
        expect(stats_key_to_csv.errored?).to be true
      end
    end

    context 'when the input does not contain errors' do
      let(:stats_key_to_csv) do
        StatsKeys2CSV.new(input: StringIO.new(valid_input_lines.join("\n")),
                          output: StringIO.new,
                          error: StringIO.new)
      end

      before do
        stats_key_to_csv.to_csv!
      end

      it 'returns false' do
        expect(stats_key_to_csv.errored?).to be false
      end
    end
  end
end
