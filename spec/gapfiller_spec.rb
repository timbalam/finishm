require 'systemu'
require 'tempfile'
require 'bio'
require 'bio-commandeer'
require 'spec_helper'

describe 'finishm gap closer' do
  path_to_script = File.join(File.dirname(__FILE__),'..','bin','finishm gapfill')
  sequence3_wtih_gaps = 'GCTGGCGGCGTGCCTAACACATGTAAGTCGAACGGGACTGGGGGCAACTCCAGTTCAGTGGCAGACGGGTGCGTAACACGTGAGCAACTTGTCCGACGGCGGGGGATAGCCGGCCCAACGGCCGGGTAATACCGCGTACGCTCGTTTAGGGACATCCCTGAATGAGGAAAGCCGTAAGGCACCGACGGAGAGGCTCGCGGCCTATCAGCTAGTTGGCGGGGTAACGGCCCACCAAGGCGACGACGGGTAGCTGGTCTGAGAGGATGGCCAGCCACATTGGGACTGAGACACGGCCCAGACTCCTACGGGAGGCAGCAGTGGGGAATCTTGCGCAATGGCCGCAAGGCTGACGCAGCGACGCCGCGTGTGGGATGACGGCCTTCGGGTTGTAAACCACTGTCGGGAGGAACGAATACTCGGCTAGTCCGAGGGTGACGGTACCTCCAAAGGAAGCACCGGCTAACTCC'+
    'NNNNNNNNNNNNNNNNN'+
    'AGGGCGCGTAGGTGGCCCGTTAAGTGGCTGGTGAAATCCCGGGGCTCAACTCCGGGGCTGCCGGTCAGACTGGCGAGCTAGAGCACGGTAGGGGCAGATGGAATTCCCGGTGTAGCGGTGGAATGCGTAGATATCGGGAAGAATACCAGTGGCGAAGGCGTTCTGCTGGGCCGTTGCTGACACTGAGGCGCGACAGCGTGGGGAGCAAACAGGATTAGATACCCTGGTAGTCCACGCCGTAAACGATGGACACTAGACGTCGGGGGGAGCGACCCTCCCGGTGTCGTCGCTAACGCAGTAAGTGTCCCGCCTGGGGAGTACGGCCGCAAGGCTGAAACTCAAAGGAATTGACGGGGGCCCGCACAAGCGGTGGAGCATGTGGTTTAATTCGAAGCAACGCGAAGAACCTTACCTGGGCTTGACATGCTGGTGCAAGCCGGTGGAAACATCGGCCCCTCTTCGGAGCGCCAGCAC'
  sequence3 = 'GCTGGCGGCGTGCCTAACACATGTAAGTCGAACGGGACTGGGGGCAACTCCAGTTCAGTGGCAGACGGGTGCGTAACACGTGAGCAACTTGTCCGACGGCGGGGGATAGCCGGCCCAACGGCCGGGTAATACCGCGTACGCTCGTTTAGGGACATCCCTGAATGAGGAAAGCCGTAAGGCACCGACGGAGAGGCTCGCGGCCTATCAGCTAGTTGGCGGGGTAACGGCCCACCAAGGCGACGACGGGTAGCTGGTCTGAGAGGATGGCCAGCCACATTGGGACTGAGACACGGCCCAGACTCCTACGGGAGGCAGCAGTGGGGAATCTTGCGCAATGGCCGCAAGGCTGACGCAGCGACGCCGCGTGTGGGATGACGGCCTTCGGGTTGTAAACCACTGTCGGGAGGAACGAATACTCGGCTAGTCCGAGGGTGACGGTACCTCCAAAGGAAGCACCGGCTAACTCCGTGCCAGCAGCCGCGGTAATACGGAGGGTGCGAGCGTTGTCCGGAATCACTGGGCGTAAAGGGCGCGTAGGTGGCCCGTTAAGTGGCTGGTGAAATCCCGGGGCTCAACTCCGGGGCTGCCGGTCAGACTGGCGAGCTAGAGCACGGTAGGGGCAGATGGAATTCCCGGTGTAGCGGTGGAATGCGTAGATATCGGGAAGAATACCAGTGGCGAAGGCGTTCTGCTGGGCCGTTGCTGACACTGAGGCGCGACAGCGTGGGGAGCAAACAGGATTAGATACCCTGGTAGTCCACGCCGTAAACGATGGACACTAGACGTCGGGGGGAGCGACCCTCCCGGTGTCGTCGCTAACGCAGTAAGTGTCCCGCCTGGGGAGTACGGCCGCAAGGCTGAAACTCAAAGGAATTGACGGGGGCCCGCACAAGCGGTGGAGCATGTGGTTTAATTCGAAGCAACGCGAAGAACCTTACCTGGGCTTGACATGCTGGTGCAAGCCGGTGGAAACATCGGCCCCTCTTCGGAGCGCCAGCAC'

  it 'should scripting test ok with a 1 node thing' do
    command = "#{path_to_script} --quiet --fasta-gz #{TEST_DATA_DIR}/gapfilling/3/reads.fa.gz --contigs #{TEST_DATA_DIR}/gapfilling/3/with_gaps.fa --output-fasta /dev/stdout"
    Bio::Commandeer.run(command).should == ">1111883_chopped_1-1000_with_some_gap_characters\n"+sequence3+"\n"
  end

  it 'should work with a 1 node but in reverse thing' do
    revseq = Bio::Sequence::NA.new(sequence3_wtih_gaps).reverse_complement.to_s.upcase

    rev = ">rev\n"+revseq
    command = "#{path_to_script} --quiet --fasta-gz #{TEST_DATA_DIR}/gapfilling/3/reads.fa.gz --contigs /dev/stdin --output-fasta /dev/stdout"
    stdout = Bio::Commandeer.run(command, :stdin => rev)

    stdout.should == ">rev\n" + Bio::Sequence::NA.new(sequence3).reverse_complement.to_s.upcase + "\n"
  end

  it 'should work when there is 2 gaps' do
    input_seq = sequence3[0...300]+
      ('N'*30)+
      sequence3[350...600]+
      ('N'*13)+
      sequence3[610..-1]
    input = ">input2gaps\n"+input_seq
    command = "#{path_to_script} --quiet --fasta-gz #{TEST_DATA_DIR}/gapfilling/3/reads.fa.gz --contigs /dev/stdin --output-fasta /dev/stdout"
    stdout = Bio::Commandeer.run(command, :stdin => input)
    stdout.should == ">input2gaps\n" + sequence3 + "\n"
  end

  it 'should work when there is 2 separate sequences' do
    sequence2 = 'AGAGTTTGATCATGGCTCAGGATGAACGCTAGCGGCAGGCCTAACACATGCAAGTCGAGGGGTAGAGGCTTTCGGGCCTTGAGACCGGCGCACGGGTGCGTAACGCGTATGCAATCTGCCTTGTACTAAGGGATAGCCCAGAGAAATTTGGATTAATACCTTATAGTATATAGATGTGGCATCACATTTCTATTAAAGATTTATCGGTACAAGATGAGCATGCGTCCCATTAGCTAGTTGGTATGGTAACGGCATACCAAGGCAATGATGGGTAGGGGTCCTGAGAGGGAGATCCCCCACACTGGTACTGAGACACGGACCAGACTCCTACGGGAGGCAGCAGTGAGGAATATTGGTCAATGGGCGCAAGCCTGAACCAGCCATGCCGCGTGCAGGATGACGGTCCTATGGATTGTAAACTGCTTTTGTACGGGAAGAAACACTCCTACGTGTAGGGGCTTGACGGTACCGTAAGAATAAGGATCGGCTAACTCCGTGCCAGCAGCCGCGGTAATACGGAGGATCCAAGCGTTATCCGGAATCATTGGGTTTAAAGGGTCCGTAGGCGGTTTTATAAGTCAGTGGTGAAATCCGGCAGCTCAACTGTCGAACTGCCATTGATACTGTAGAACTTGAATTACTGTGAAGTAACTAGAATATGTAGTGTAGCGGTGAAATGCTTAGATATTACATGGAATACCAATTGCGAAGGCAGGTTACTAACAGTATATTGACGCTGATGGACGAAAGCGTGGGGAGCGAACAGGATTAGATACCCTGGTAGTCCACGCCGTAAACGATGGATACTAGCTGTTTGGCAGCAATGCTGAGTGGCTAAGCGAAAGTGTTAAGTATCCCACCTGGGGAGTACGAACGCAAGTTTGAAACTCAAAGGAATTGACGGGGGCCCGCACAAGCGGTGGAGCATGTGGTTTAATTCGATGATACGCGAGGAACCTTACCAGGGCTTAAATGTAGAGTGACAGGACTGGAAACAGTTTTTTCTTCGGACACTTTACAAGGTGCTGCATGGTTGTCGTCAGCTCGTGCCGTGAGGTGTCAGGTTAAGTCCTATAACGAGCGCAACCCCTGTTGTTAGTTGCCAGCGAGTAATGTCGGGAACTCTAACAAGACTGCCGGTGCAAACCGTGAGGAAGGTGGGGATGACGTCAAATCATCACGGCCCTTACGTCCTGGGCTACACACGTGCTACAATGGCCGGTACAGAGAGCAGCCACCTCGCGAGGGGGAGCGAATCTATAAAGCCGGTCACAGTTCGGATTGGAGTCTGCAACCCGACTCCATGAAGCTGGAATCGCTAGTAATCGGATATCAGCCATGATCCGGTGAATACGTTCCCGGGCCTTGTACACACCGCCCGTCAAGCCATGGAAGCTGGGGGTACCTGAAGTCGGTGACCGCAAGGAGCTGCCTAGGGTAAAACTGGTAACTGGGGCTAAGTCGTACAAGGTAGCCGTA'
    input = [
      ">seq1",
      sequence3_wtih_gaps,
      ">seq2",
      sequence2[0..300],
        'N'*50,
      sequence2[400..-1]
      ].join("\n")
    command = "#{path_to_script} --quiet --fasta-gz #{TEST_DATA_DIR}/gapfilling/3/reads.fa.gz,#{TEST_DATA_DIR}/gapfilling/4/reads.fa.gz, --contigs /dev/stdin --output-fasta /dev/stdout"
    stdout = Bio::Commandeer.run(command, :stdin => input)
    stdout.should == ">seq1\n" + sequence3 + "\n>seq2\n" + sequence2+"\n"
  end

  it 'should not connect gaps when there is no gap to connect' do
    sequence2 = 'AGAGTTTGATCATGGCTCAGGATGAACGCTAGCGGCAGGCCTAACACATGCAAGTCGAGGGGTAGAGGCTTTCGGGCCTTGAGACCGGCGCACGGGTGCGTAACGCGTATGCAATCTGCCTTGTACTAAGGGATAGCCCAGAGAAATTTGGATTAATACCTTATAGTATATAGATGTGGCATCACATTTCTATTAAAGATTTATCGGTACAAGATGAGCATGCGTCCCATTAGCTAGTTGGTATGGTAACGGCATACCAAGGCAATGATGGGTAGGGGTCCTGAGAGGGAGATCCCCCACACTGGTACTGAGACACGGACCAGACTCCTACGGGAGGCAGCAGTGAGGAATATTGGTCAATGGGCGCAAGCCTGAACCAGCCATGCCGCGTGCAGGATGACGGTCCTATGGATTGTAAACTGCTTTTGTACGGGAAGAAACACTCCTACGTGTAGGGGCTTGACGGTACCGTAAGAATAAGGATCGGCTAACTCCGTGCCAGCAGCCGCGGTAATACGGAGGATCCAAGCGTTATCCGGAATCATTGGGTTTAAAGGGTCCGTAGGCGGTTTTATAAGTCAGTGGTGAAATCCGGCAGCTCAACTGTCGAACTGCCATTGATACTGTAGAACTTGAATTACTGTGAAGTAACTAGAATATGTAGTGTAGCGGTGAAATGCTTAGATATTACATGGAATACCAATTGCGAAGGCAGGTTACTAACAGTATATTGACGCTGATGGACGAAAGCGTGGGGAGCGAACAGGATTAGATACCCTGGTAGTCCACGCCGTAAACGATGGATACTAGCTGTTTGGCAGCAATGCTGAGTGGCTAAGCGAAAGTGTTAAGTATCCCACCTGGGGAGTACGAACGCAAGTTTGAAACTCAAAGGAATTGACGGGGGCCCGCACAAGCGGTGGAGCATGTGGTTTAATTCGATGATACGCGAGGAACCTTACCAGGGCTTAAATGTAGAGTGACAGGACTGGAAACAGTTTTTTCTTCGGACACTTTACAAGGTGCTGCATGGTTGTCGTCAGCTCGTGCCGTGAGGTGTCAGGTTAAGTCCTATAACGAGCGCAACCCCTGTTGTTAGTTGCCAGCGAGTAATGTCGGGAACTCTAACAAGACTGCCGGTGCAAACCGTGAGGAAGGTGGGGATGACGTCAAATCATCACGGCCCTTACGTCCTGGGCTACACACGTGCTACAATGGCCGGTACAGAGAGCAGCCACCTCGCGAGGGGGAGCGAATCTATAAAGCCGGTCACAGTTCGGATTGGAGTCTGCAACCCGACTCCATGAAGCTGGAATCGCTAGTAATCGGATATCAGCCATGATCCGGTGAATACGTTCCCGGGCCTTGTACACACCGCCCGTCAAGCCATGGAAGCTGGGGGTACCTGAAGTCGGTGACCGCAAGGAGCTGCCTAGGGTAAAACTGGTAACTGGGGCTAAGTCGTACAAGGTAGCCGTA'
    input = [
      ">seq2",
      sequence2[0..300]+
        'N'*50+
        sequence2[400..-1]
      ].join("\n")
    # 3/reads.fa.gz is the wrong set of reads, so no connection should be made
    command = "#{path_to_script} --quiet --fasta-gz #{TEST_DATA_DIR}/gapfilling/3/reads.fa.gz --contigs /dev/stdin --output-fasta /dev/stdout"
    stdout = Bio::Commandeer.run(command, :stdin => input)
    stdout.should == input+"\n"
  end

  it 'should take into account the position of the probe on the starting node' do
    fail
  end

  it 'should work with recoherence' do
    # this example is setup so that requires recoherence, not just 51mers
    cmd = "#{path_to_script} --contigs #{TEST_DATA_DIR}/gapfilling/6/to_gapfill.fa --output-fasta /dev/stdout --fasta-gz #{TEST_DATA_DIR}/gapfilling/6/reads.random1.fa.gz,#{TEST_DATA_DIR}/gapfilling/6/reads.random2.fa.gz --recoherence-kmer 90 --overhang 75"
    expected = <<END
>random_sequence_length_2000
GCGGGGCAGGTGATCGGGGCCTATTCATTCCTGTATGAAATATAGTTTCCGAACTGACAAACGGATAGTAGCCCAGGTCTAACAGTTTCCAGATTAAATGAATGATGTTCAACGCGTTTCCAAGAACATCCGGGGCCTCCATCGCGCAATTGTGCCCAATCTAGGGACCGCTAGGGAGCTCCCCCAGGTAAAGGAGGTGATGGCGGTAGTCTGCTCGTTGAATTTTTTGAACTTTCGAGTTGGGAACCGTTGCAACGATCAATCGGTTTTGCCGAATCCCCACCCTATTACTAGTGATGCGCATTTGCAGCGCGAGGTCATTAGACAGTCACAATCTTAGGATTTTACGCATTCCATATTTACTCCTAACTCTAAAGAGTTCCCGTGCAGGTCTAGCCTGGCTAACATGCCCTCTCCGGCACAGACTGTCATTATGAAGCGACAGCCTAACCCGGGCGCTCTCTTGAAATCGCAGAGTAATATCTCCGTATACGCTCATCAGTTGCGGTCGACGTCGACTACGGCACGGAGTCCCAGCCCGAGCCACCCATGTAAAACACGCGACCTGGAGGCCTGCTTAAAAACACTTCAGACAATCGAATTCACACTGTCCCAAATCCTGAGGGGTGAACGTTCCGAACGCAATGTGAAGAACTGACAAGTGGTTATGGACGCGGCGATGGTTGTTCCAACAATACGCTCGAATCGGGGCTCCCGATGCAAGCATTGATAAATCTCCAATGTATAGGATAGTCGGGCCAGTATGCATCTGAAGTGGCCAAAACCAACAACCGACCCGAAATATATTTCATTACCAAACTAACGTAGGCGTCTGCTCACGAAATTTTGAGTAATCACCGTGTTCGGCATTTGCGTCCCAGAGTTGACTTTACCGGAATACGGGGTGGCCACCGGTTTTTTAACGTACCAGGCCCGAGAAAGACAAATAGAAACGTTTGATGCCGTAGAATGACCCACGCTTCGTATATCTTGCCTATGGTTTTTATTTTAGTGACGTTTTCTCACGGCGCTGCGCGGTCGTTCCGAATCTGCTGTCCACCGAAATGTTTCTGTGCGATCAGGCCACGTGACTTCATACGGGGAGCATCTATACCTTGGCATGCGAGTACGTGTGCGTATGCATCAAGTATCCTGAAAACTACATCATGTTCGTTTCAAACACTCGCGAGTTTAGTTCCGATACACGATGGCGGAGGCGAGTTCCAGGTTGGCGCACTCTAAAGGAATAACAGATCGGGTCTTATGCAGAGGAAGGAAACACGGCCACGCATAGTCGCGGGGGGGCTCCCAGAGGCCTTTTACCCTCGTCTGCGTTTCCTTCCAGTGAGGTCGCACATAGGCCACATCGGGTAACCTTTCATTATGCTGCCGGATTGAGCTCCACCAGCATCTATGATGGGAACTAACCCGAGGAGAACGCTTGGACTTGGAACACGATATAACGCATCCATGAGTGGCTATCGTGCGGTAGTGGTGCGCTGAGAACCGCTGCTATTGTCTAGGCAGAAGTATATCTAATACCTAGCACCGTTCCCCTAATAGGTATACGTGAGGGCGTCTGCAAAGTTCCTTCAACAGCTCAGGGTCAAAATGGCATTCCCGAATCCCTATCACTCCCCACATAGGAGGTACTCGAGAGGAGTCGCGAGGCGGAGGCCCATCATTGGTTGCGCTCAACCCACTAGGTAACAATGCGACTAGCCCCGTGGTTTAACCGCCGGTTAGTGCCCATCCGCCTGGATCCAAAACCAATTCCCGGTCGCACTTCCTACCCAGCACATGGGCGCAGGAGCTCGTTCAAACATCGTTAGTCCCTTTGCTGCGGGCGTTTTTAAGTAGGTAAGACATTCTAACTCTCCTTATTATGCCTAATCCTTTGACCCGATAAGTGAGAACCGGTCAACTGAGGGTTTGCCCAGCTCCCCCCGCTGCTGTAAACCCGGCCACTCCTCGGGTCGTTGCGTGGGCTCCACCGTCAC
END
    Bio::Commandeer.run(cmd).should == expected

    # check that the recoherence way isn't good enough
    cmd = "#{path_to_script} --contigs #{TEST_DATA_DIR}/gapfilling/6/to_gapfill.fa --output-fasta /dev/stdout --fasta-gz #{TEST_DATA_DIR}/gapfilling/6/reads.random1.fa.gz,#{TEST_DATA_DIR}/gapfilling/6/reads.random2.fa.gz --overhang 75"
    expected = <<END
>random_sequence_length_2000
GCGGGGCAGGTGATCGGGGCCTATTCATTCCTGTATGAAATATAGTTTCCGAACTGACAAACGGATAGTAGCCCAGGTCTAACAGTTTCCAGATTAAATGAATGATGTTCAACGCGTTTCCAAGAACATCCGGGGCCTCCATCGCGCAATTGTGCCCAATCTAGGGACCGCTAGGGAGCTCCCCCAGGTAAAGGAGGTGATGGCGGTAGTCTGCTCGTTGAATTTTTTGAACTTTCGAGTTGGGAACCGTTGCAACGATCAATCGGTTTTGCCGAATCCCCACCCTATTACTAGTGATGCGCATTTGCAGCGCGAGGTCATTAGACAGTCACAATCTTAGGATTTTACGCATTCCATATTTACTCCTAACTCTAAAGAGTTCCCGTGCAGGTCTAGCCTGGCTAACATGCCCTCTCCGGCACAGACTGTCATTATGAAGCGACAGCCTAACCCGGGCGCTCTCTTGAAATCGCAGAGTAATATCTCCGTATACGCTCATCAGTTGCGGTCGACGTCGACTACGGCACGGAGTCCCAGCCCGAGCCACCCATGTAAAACACGCGACCTGGAGGCCTGCTTAAAAACACTTCAGACAATCGAATTCACACTGTCCCAAATCCTGAGGGGTGAACGTTCCGAACGCAATGTGAAGAACTGACAAGTGGTTATGGACGCGGCGATGGTTGTTCCAACAATACGCTCGAATCGGGGCTCCCGATGNNNNATGCGAGTACGTGTGCGTATGCATCAAGTATCCTGAAAACTACATCATGTTCGTTTCAAACACTCGCGAGTTTAGTTCCGATACACGATGGCGGAGGCGAGTTCCAGGTTGGCGCACTCTAAAGGAATAACAGATCGGGTCTTATGCAGAGGAAGGAAACACGGCCACGCATAGTCGCGGGGGGGCTCCCAGAGGCCTTTTACCCTCGTCTGCGTTTCCTTCCAGTGAGGTCGCACATAGGCCACATCGGGTAACCTTTCATTATGCTGCCGGATTGAGCTCCACCAGCATCTATGATGGGAACTAACCCGAGGAGAACGCTTGGACTTGGAACACGATATAACGCATCCATGAGTGGCTATCGTGCGGTAGTGGTGCGCTGAGAACCGCTGCTATTGTCTAGGCAGAAGTATATCTAATACCTAGCACCGTTCCCCTAATAGGTATACGTGAGGGCGTCTGCAAAGTTCCTTCAACAGCTCAGGGTCAAAATGGCATTCCCGAATCCCTATCACTCCCCACATAGGAGGTACTCGAGAGGAGTCGCGAGGCGGAGGCCCATCATTGGTTGCGCTCAACCCACTAGGTAACAATGCGACTAGCCCCGTGGTTTAACCGCCGGTTAGTGCCCATCCGCCTGGATCCAAAACCAATTCCCGGTCGCACTTCCTACCCAGCACATGGGCGCAGGAGCTCGTTCAAACATCGTTAGTCCCTTTGCTGCGGGCGTTTTTAAGTAGGTAAGACATTCTAACTCTCCTTATTATGCCTAATCCTTTGACCCGATAAGTGAGAACCGGTCAACTGAGGGTTTGCCCAGCTCCCCCCGCTGCTGTAAACCCGGCCACTCCTCGGGTCGTTGCGTGGGCTCCACCGTCAC
END
    Bio::Commandeer.run(cmd).should == expected
  end

  it 'should skip gaps when there is insufficient hangover space' do
    sequence2 = 'AGAGTTTGATCATGGCTCAGGATGAACGCTAGCGGCAGGCCTAACACATGCAAGTCGAGGGGTAGAGGCTTTCGGGCCTTGAGACCGGCGCACGGGTGCGTAACGCGTATGCAATCTGCCTTGTACTAAGGGATAGCCCAGAGAAATTTGGATTAATACCTTATAGTATATAGATGTGGCATCACATTTCTATTAAAGATTTATCGGTACAAGATGAGCATGCGTCCCATTAGCTAGTTGGTATGGTAACGGCATACCAAGGCAATGATGGGTAGGGGTCCTGAGAGGGAGATCCCCCACACTGGTACTGAGACACGGACCAGACTCCTACGGGAGGCAGCAGTGAGGAATATTGGTCAATGGGCGCAAGCCTGAACCAGCCATGCCGCGTGCAGGATGACGGTCCTATGGATTGTAAACTGCTTTTGTACGGGAAGAAACACTCCTACGTGTAGGGGCTTGACGGTACCGTAAGAATAAGGATCGGCTAACTCCGTGCCAGCAGCCGCGGTAATACGGAGGATCCAAGCGTTATCCGGAATCATTGGGTTTAAAGGGTCCGTAGGCGGTTTTATAAGTCAGTGGTGAAATCCGGCAGCTCAACTGTCGAACTGCCATTGATACTGTAGAACTTGAATTACTGTGAAGTAACTAGAATATGTAGTGTAGCGGTGAAATGCTTAGATATTACATGGAATACCAATTGCGAAGGCAGGTTACTAACAGTATATTGACGCTGATGGACGAAAGCGTGGGGAGCGAACAGGATTAGATACCCTGGTAGTCCACGCCGTAAACGATGGATACTAGCTGTTTGGCAGCAATGCTGAGTGGCTAAGCGAAAGTGTTAAGTATCCCACCTGGGGAGTACGAACGCAAGTTTGAAACTCAAAGGAATTGACGGGGGCCCGCACAAGCGGTGGAGCATGTGGTTTAATTCGATGATACGCGAGGAACCTTACCAGGGCTTAAATGTAGAGTGACAGGACTGGAAACAGTTTTTTCTTCGGACACTTTACAAGGTGCTGCATGGTTGTCGTCAGCTCGTGCCGTGAGGTGTCAGGTTAAGTCCTATAACGAGCGCAACCCCTGTTGTTAGTTGCCAGCGAGTAATGTCGGGAACTCTAACAAGACTGCCGGTGCAAACCGTGAGGAAGGTGGGGATGACGTCAAATCATCACGGCCCTTACGTCCTGGGCTACACACGTGCTACAATGGCCGGTACAGAGAGCAGCCACCTCGCGAGGGGGAGCGAATCTATAAAGCCGGTCACAGTTCGGATTGGAGTCTGCAACCCGACTCCATGAAGCTGGAATCGCTAGTAATCGGATATCAGCCATGATCCGGTGAATACGTTCCCGGGCCTTGTACACACCGCCCGTCAAGCCATGGAAGCTGGGGGTACCTGAAGTCGGTGACCGCAAGGAGCTGCCTAGGGTAAAACTGGTAACTGGGGCTAAGTCGTACAAGGTAGCCGTA'
    small_seq = 'A'*50+'N'+'G'*50,
    input = [
      ">too_small",
      small_seq,
      ">seq2",
      sequence2[0..300],
        'N'*50,
      sequence2[400..-1]
      ].join("\n")
    command = "#{path_to_script} --quiet --fasta-gz #{TEST_DATA_DIR}/gapfilling/3/reads.fa.gz,#{TEST_DATA_DIR}/gapfilling/4/reads.fa.gz, --contigs /dev/stdin --output-fasta /dev/stdout"
    stdout = Bio::Commandeer.run(command, :stdin => input)
    stdout.should == ">too_small\n" + small_seq + "\n>seq2\n" + sequence2+"\n"
  end
end
