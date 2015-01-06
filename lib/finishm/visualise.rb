class Bio::FinishM::Visualiser
  include Bio::FinishM::Logging

  def add_options(optparse_object, options)
    optparse_object.banner = "\nUsage: finishm visualise --assembly-??? <output_visualisation_file>

    Visualise an assembly graph
    \n\n"

    options.merge!({
      :graph_search_leash_length => 20000,
      :interesting_probes => nil,
      :contig_end_length => 200,
    })
    optparse_object.separator "Output visualisation formats (one or more of these must be used)"
    optparse_object.on("--assembly-svg PATH", "Output assembly as a SVG file [default: off]") do |arg|
      options[:output_graph_svg] = arg
    end
    optparse_object.on("--assembly-png PATH", "Output assembly as a PNG file [default: off]") do |arg|
      options[:output_graph_png] = arg
    end
    optparse_object.on("--assembly-dot PATH", "Output assembly as a DOT file [default: off]") do |arg|
      options[:output_graph_dot] = arg
    end
    optparse_object.on("--genomes FASTA_1[,FASTA_2...]", Array, "Fasta files of genomes used in the assembly. Required if --scaffolds is given [default: unused]") do |arg|
      options[:assembly_files] = arg
    end
    optparse_object.on("--overhang NUM", Integer, "Start visualising this far from the ends of the contigs [default: #{options[:contig_end_length] }]") do |arg|
      options[:contig_end_length] = arg.to_i
    end

    optparse_object.separator "\nIf an assembly is to be done, there must be some definition of reads:\n\n" #TODO improve this help
    Bio::FinishM::ReadInput.new.add_options(optparse_object, options)

    optparse_object.separator "\nOptional arguments:\n\n"
    optparse_object.on("--scaffolds SIDE_1[,SIDE_2...]", Array, "visualise from these scaffold ends e.g 'contig1s' for the start of contig1, 'contig1e' for the end of contig1, and 'contig1,contig3e' for both sides of contig1 and the end of contig3 [default: unused]") do |arg|
      options[:scaffold_sides] = arg.collect do |side|
        if side.match(/[se]$/)
          side
        else
          ["#{side}s","#{side}e"]
        end
      end.flatten
    end
    optparse_object.on("--probe-ids PROBE_IDS", Array, "explore from these probe IDs in the graph (comma separated). probe ID is the ID in the velvet Sequence file. See also --leash-length [default: don't start from a node, explore the entire graph]") do |arg|
      options[:interesting_probes] = arg.collect do |read|
        read_id = read.to_i
        if read_id.to_s != read or read_id.nil? or read_id < 1
          raise "Unable to parse probe ID #{read}, from #{arg}, cannot continue"
        end
        read_id
      end
    end
    optparse_object.on("--probe-ids-file PROBE_IDS_FILE", String, "explore from the probe IDs given in the file (1 probe ID per line). See also --leash-length [default: don't start from a node, explore the entire graph]") do |arg|
      raise "Cannot specify both --probe-ids and --probe-ids-file sorry" if options[:interesting_probes]
      options[:interesting_probes] = []
      log.info "Reading probe IDs from file: `#{arg}'"
      File.foreach(arg) do |line|
        line.strip!
        next if line == '' or line.nil?
        read_id = line.to_i
        if read_id.to_s != line or read_id < 1 or read_id.nil?
          raise "Unable to parse probe ID #{line}, from file #{arg}, cannot continue"
        end
        options[:interesting_probes].push read_id
      end
      log.info "Read #{options[:interesting_probes].length} probes in"
    end
    optparse_object.on("--probe-names-file PROBE_NAMES_FILE", String, "explore from the probe names (i.e. the first word in the fasta/fastq header) given in the file (1 probe name per line). See also --leash-length [default: don't start from a node, explore the entire graph]") do |arg|
      raise "Cannot specify any two of --probe-names-file, --probe-ids and --probe-ids-file sorry" if options[:interesting_probes]
      options[:interesting_probe_names] = []
      log.info "Reading probe names from file: `#{arg}'"
      File.foreach(arg) do |line|
        line.strip!
        next if line == '' or line.nil?
        options[:interesting_probe_names].push line
      end
      log.info "Read #{options[:interesting_probe_names].length} probes names in"
    end
    optparse_object.on("--node-ids NODE_IDS", Array, "explore from these nodes in the graph (comma separated). Node IDs are the nodes in the velvet graph. See also --leash-length [default: don't start from a node, explore the entire graph]") do |arg|
      options[:interesting_nodes] = arg.collect do |read|
        node_id = read.to_i
        if node_id.to_s != read or node_id.nil? or node_id < 1
          raise "Unable to parse node ID #{read}, from #{arg}, cannot continue"
        end
        node_id
      end
    end
    optparse_object.on("--probe-to-node-map FILE", String, "Output a tab separated file containing the read IDs and their respective node IDs [default: no output]") do |arg|
      options[:probe_to_node_map] = arg
    end
    optparse_object.on("--leash-length NUM", Integer, "Don't explore too far in the graph, only this far and not much more [default: unused unless --probe-ids or --nodes is specified, otherwise #{options[:graph_search_leash_length] }]") do |arg|
      options[:graph_search_leash_length] = arg
    end

    optparse_object.separator "\nOptional graph-related arguments:\n\n"
    Bio::FinishM::GraphGenerator.new.add_options optparse_object, options
  end

  def validate_options(options, argv)
    #TODO: give a better description of the error that has occurred
    #TODO: require reads options
    if argv.length != 0
      return "Dangling argument(s) found e.g. #{argv[0] }"
    else
      if options[:output_graph_png].nil? and options[:output_graph_svg].nil? and options[:output_graph_dot].nil?
        return "No visualisation output format/file given, don't know how to visualise"
      end

      # If scaffolds are defined, then probe genomes must also be defined
      if options[:scaffolds] and !options[:genome_files]
        return "If --scaffolds is defined, so then must --genomes"
      end

      #TODO: this needs to be improved.
      if options[:interesting_probes] and options[:interesting_nodes]
        return "Can only be interested in probes or nodes, not both, at least currently"
      end

      # Need reads unless there is already an assembly
      unless options[:previous_assembly] or options[:previously_serialized_parsed_graph_file]
        return Bio::FinishM::ReadInput.new.validate_options(options, [])
      else
        return nil
      end

    end
  end

  def run(options, argv)
    read_input = Bio::FinishM::ReadInput.new
    read_input.parse_options options

    # Generate the assembly graph
    log.info "Reading in or generating the assembly graph"
    viser = Bio::Assembly::ABVisualiser.new
    gv = nil

    if options[:interesting_probes] or options[:interesting_probe_names]
      # Looking based on probes
      if options[:interesting_probe_names]
        log.info "Targeting #{options[:interesting_probe_names].length} probes through their names e.g. `#{options[:interesting_probe_names] }'"
        options[:probe_read_names] = options[:interesting_probe_names]
      else
        if options[:interesting_probes].length > 5
          log.info "Targeting #{options[:interesting_probes].length} probes #{options[:interesting_probes][0..4].join(', ') }, ..."
        else
          log.info "Targeting #{options[:interesting_probes].length} probes #{options[:interesting_probes].inspect}"
        end
        options[:probe_reads] = options[:interesting_probes]
      end

      options[:dont_parse_reads] = true #the sequences of the reads themselves are not of use
      finishm_graph = Bio::FinishM::GraphGenerator.new.generate_graph([], read_input, options)

      # Output probe map if asked
      if options[:probe_to_node_map]
        write_probe_to_node_map(options[:probe_to_node_map], finishm_graph, options[:interesting_probes])
      end

      # Create graphviz object
      interesting_node_ids = finishm_graph.probe_nodes.reject{|n| n.nil?}.collect{|node| node.node_id}

      nodes_within_leash, node_ids_at_leash = get_nodes_within_leash(finishm_graph, interesting_node_ids, options)
      log.info "Found #{node_ids_at_leash.length} nodes at the end of the #{options[:leash_length] }bp leash" if options[:leash_length]

      # Determine paired-end connections
      log.info "Determining paired-end node connections.."
      paired_end_links = find_paired_end_linkages(finishm_graph, nodes_within_leash)

      log.info "Converting assembly to a graphviz"
      gv = viser.graphviz(finishm_graph.graph, {
        :start_node_ids => interesting_node_ids,
        :nodes => nodes_within_leash,
        :end_node_ids => node_ids_at_leash,
        :paired_nodes_hash => paired_end_links,
        })


    elsif options[:interesting_nodes]
      # Looking based on nodes
      if options[:interesting_nodes].length > 5
        log.info "Targeting #{options[:interesting_nodes].length} nodes #{options[:interesting_nodes][0..4].join(', ') }, ..."
      else
        log.info "Targeting #{options[:interesting_nodes].length} node(s) #{options[:interesting_nodes].inspect}"
      end
      options[:dont_parse_noded_reads] = true
      options[:dont_parse_reads] = true
      finishm_graph = Bio::FinishM::GraphGenerator.new.generate_graph([], read_input, options)

      log.info "Finding nodes within the leash length of #{options[:graph_search_leash_length] }.."
      nodes_within_leash, node_ids_at_leash = get_nodes_within_leash(finishm_graph, options[:interesting_nodes], options)
      log.info "Found #{node_ids_at_leash.length} nodes at the end of the #{options[:leash_length] }bp leash" if options[:leash_length]

      # Determine paired-end connections
      log.info "Determining paired-end node connections.."
      paired_end_links = find_paired_end_linkages(finishm_graph, nodes_within_leash)

      log.info "Converting assembly to a graphviz"
      gv = viser.graphviz(finishm_graph.graph, {
        :start_node_ids => options[:interesting_nodes],
        :nodes => nodes_within_leash,
        :end_node_ids => node_ids_at_leash,
        :paired_nodes_hash => paired_end_links,
        })

    elsif options[:assembly_files]
      # Parse the genome fasta file in
      genomes = Bio::FinishM::InputGenome.parse_genome_fasta_files(
        options[:assembly_files],
        options[:contig_end_length],
        options
        )

      # Create hash of contig end name to probe index
      contig_name_to_probe = {}
      genomes.each do |genome|
        genome.scaffolds.each_with_index do |swaff, scaffold_index|
          probes = [
            genome.first_probe(scaffold_index),
            genome.last_probe(scaffold_index)
            ]
          probes.each do |probe|
            key = nil
            if probe.side == :start
              key = "#{probe.contig.scaffold.name}s"
            elsif probe.side == :end
              key = "#{probe.contig.scaffold.name}e"
            else
              raise "Programming error"
            end

            if contig_name_to_probe.key?(key)
              log.error "Encountered multiple contigs with the same name, this might cause problems, so quitting #{key}"
            end
            contig_name_to_probe[key] = probe.index
          end
        end
      end

      # Gather a list of probe indexes that are of interest to the user
      interesting_probe_ids = []
      if options[:scaffold_sides]
        # If looking at specified ends
        nodes_to_start_from = options[:scaffold_sides].collect do |side|
          if probe = contig_name_to_probe[side]
            interesting_probe_ids << probe
          else
            raise "Unable to find scaffold side in given genome: #{side}"
          end
        end
        log.info "Found #{interesting_probe_ids.length} scaffold sides in the assembly of interest"
      else
        # else looking at all the contig ends in all the genomes
        interesting_probe_ids = contig_name_to_probe.values
        log.info "Visualising all #{interesting_probe_ids.length} contig ends in all genomes"
      end

      # Generate the graph
      probe_sequences = genomes.collect{|genome| genome.probe_sequences}.flatten
      finishm_graph = Bio::FinishM::GraphGenerator.new.generate_graph(probe_sequences, read_input, options)

      # Convert probe IDs into node IDs
      interesting_node_ids = interesting_probe_ids.collect do |pid|
        finishm_graph.probe_nodes[pid].node_id
      end.uniq

      # get a list of the nodes to be visualised given the leash length
      nodes_within_leash, node_ids_at_leash = get_nodes_within_leash(finishm_graph, interesting_node_ids, options)
      log.info "Found #{node_ids_at_leash.length} nodes at the end of the #{options[:leash_length] }bp leash" if options[:leash_length]

      # create a nickname hash, id of node to name. Include all nodes even if they weren't specified directly (they only get visualised if they are within leash length of another)
      node_id_to_nickname = {}
      contig_name_to_probe.each do |name, probe|
        key = finishm_graph.probe_nodes[probe].node_id
        if node_id_to_nickname.key?(key)
          node_id_to_nickname[key] += " "+name
        else
          node_id_to_nickname[key] = name
        end
      end

      # Determine paired-end connections
      log.info "Determining paired-end node connections.."
      paired_end_links = find_paired_end_linkages(finishm_graph, nodes_within_leash)

      # create gv object
      log.info "Converting assembly to a graphviz"
      gv = viser.graphviz(finishm_graph.graph, {
        :start_node_ids => interesting_node_ids,
        :nodes => nodes_within_leash,
        :end_node_ids => node_ids_at_leash,
        :node_id_to_nickname => node_id_to_nickname,
        :paired_nodes_hash => paired_end_links,
        })
    else
      # Visualising the entire graph
      finishm_graph = Bio::FinishM::GraphGenerator.new.generate_graph([], read_input, options)

      # Determine paired-end connections
      log.info "Determining paired-end node connections.."
      paired_end_links = find_paired_end_linkages(finishm_graph, finishm_graph.graph.nodes)

      log.info "Converting assembly to a graphviz.."
      gv = viser.graphviz(finishm_graph.graph, :paired_nodes_hash => paired_end_links)
    end

    # Convert gv object to something actually pictorial
    if options[:output_graph_png]
      log.info "Writing PNG #{options[:output_graph_png] }"
      gv.output :png => options[:output_graph_png], :use => :neato
    end
    if options[:output_graph_svg]
      log.info "Writing SVG #{options[:output_graph_svg] }"
      gv.output :svg => options[:output_graph_svg], :use => :neato
    end
    if options[:output_graph_dot]
      log.info "Writing DOT #{options[:output_graph_dot] }"
      gv.output :dot => options[:output_graph_dot], :use => :neato
    end
  end

  def get_nodes_within_leash(finishm_graph, node_ids, options={})
    log.info "Finding nodes within the leash length of #{options[:graph_search_leash_length] }.."
    dijkstra = Bio::AssemblyGraphAlgorithms::Dijkstra.new
    finder = Bio::FinishM::PairedEndNeighbourFinder.new(finishm_graph, 500) #TODO: this hard-coded 100 isn't great here

    nodes_within_leash_hash = dijkstra.min_distances_from_many_nodes_in_both_directions(
      finishm_graph.graph, node_ids.collect{|n| finishm_graph.graph.nodes[n]}, {
        :ignore_directions => true,
        :leash_length => options[:graph_search_leash_length],
        :neighbour_finder => finder
        })
    nodes_within_leash = nodes_within_leash_hash.keys.collect{|k| finishm_graph.graph.nodes[k[0]]}
    log.info "Found #{nodes_within_leash.collect{|o| o.node_id}.uniq.length} node(s) within the leash length"

    # These nodes are at the end of the leash - a node is in here iff
    # it has a neighbour that is not in the nodes_within_leash
    node_ids_at_leash = Set.new
    nodes_within_leash_hash.keys.each do |node_and_direction|
      # Add it to the set if 1 or more nieghbours are not in the original set
      node = finishm_graph.graph.nodes[node_and_direction[0]]
      onode = Bio::Velvet::Graph::OrientedNodeTrail::OrientedNode.new node, node_and_direction[1]
      onode.next_neighbours(finishm_graph.graph).each do |oneigh|
        if !nodes_within_leash_hash.key?(oneigh.to_settable)
          node_ids_at_leash << node_and_direction[0]
          break #it only takes one to be listed
        end
      end
    end

    return nodes_within_leash.uniq, node_ids_at_leash.to_a.uniq
  end

  # Write to a file probe_to_node_map_file a map that shows the
  # probe ID, which node that probe is on, and the name of the probe
  def write_probe_to_node_map(probe_to_node_map_file, finishm_graph, names)
    log.info "Writing probe-to-node map to #{x}.."
    File.open(probe_to_node_map_file,'w') do |f|
      f.puts %w(probe_number probe node direction).join("\t")
      finishm_graph.probe_nodes.each_with_index do |node, i|
        if node.nil?
          f.puts [
            i+1,
            names[i],
            '-',
            '-',
            ].join("\t")
        else
          f.puts [
            i+1,
            names[i],
            node.node_id,
            finishm_graph.probe_node_directions[i] == true ? 'forward' : 'reverse',
            ].join("\t")
        end
      end
    end
  end

  def find_paired_end_linkages(finishm_graph, node_array)
    paired_end_links = {}
    node_array.each do |node|
      paired_end_links[node.node_id] = finishm_graph.paired_nodes(node)
    end
    return paired_end_links
  end
end
