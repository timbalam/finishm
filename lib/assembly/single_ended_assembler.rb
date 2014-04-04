require 'ds'
require 'set'

class Bio::AssemblyGraphAlgorithms::SingleEndedAssembler
  include Bio::FinishM::Logging

  # Assemble considering reads all reads as single ended. Options:
  # :max_tip_length: if a path is shorter than this in bp, then it will be clipped from the path. Default 100
  def assemble_from(initial_path, graph, options={})
    options[:max_tip_length] ||= 100

    path = initial_path.copy
    while true
      log.debug "Starting from #{path[-1].to_shorthand}" if log.debug?
      oneighbours = path.neighbours_of_last_node(graph)
      if oneighbours.length == 0
        log.debug "Found a dead end, last node is #{path[-1].to_shorthand}" if log.debug?
        return path

      elsif oneighbours.length == 1
        to_add = oneighbours[0]
        log.debug "Only one way to go, so going there, to #{to_add.to_shorthand}" if log.debug?
        path.add_oriented_node to_add

      else
        # Reached a fork, which way to go?

        # Remove neighbours that are short tips
        oneighbours.reject! do |oneigh|
          is_short_tip?(oneigh, graph, options[:max_tip_length])
        end

        if oneighbours.length == 0
          log.debug "Found a dead end at a fork, last node is #{path[-1].to_shorthand}" if log.debug?
          return path
        elsif oneighbours.length == 1
          log.debug "Clipped short tip(s) off, and then there was only one way to go" if log.debug?
          path.add_oriented_node oneighbours[0]
        else
          log.debug "Came across what appears to be a legitimate fork, so giving up" if log.debug?
          return path
        end
      end
    end

    return path
  end

  # Returns false iff there is a path longer than max_tip_length
  # starting at the given oriented_node. Currently works like Dijkstra's
  # shortest path algorithm except that it finds the longest path, not the
  # shortest.
  def is_short_tip?(oriented_node, graph, max_tip_length)
    stack = DS::Stack.new
    first = MaxDistancedOrientedNode.new
    first.onode = oriented_node
    first.distance = oriented_node.node.length_alone
    stack.push first

    cache = {}

    while current_max_distanced_onode = stack.pop
      return false if current_max_distanced_onode.distance > max_tip_length

      current_max_distanced_onode.onode.next_neighbours(graph).each do |oneigh|
        neighbour_distance = current_max_distanced_onode.distance + oneigh.node.length_alone
        next if cache[oneigh.to_settable] and cache[oneigh.to_settable] >= neighbour_distance
        distanced_node = MaxDistancedOrientedNode.new
        distanced_node.onode = oneigh
        distanced_node.distance = neighbour_distance
        cache[oneigh.to_settable] = neighbour_distance
        stack.push distanced_node
      end
    end

    return true
  end

  class MaxDistancedOrientedNode
    attr_accessor :onode, :distance
  end
end
