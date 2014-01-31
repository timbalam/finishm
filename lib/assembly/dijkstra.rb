require 'ds'
require 'set'

module Bio
  module AssemblyGraphAlgorithms
    class Dijkstra
      include Bio::FinishM::Logging

      # Return an array of DistancedOrientedNode objects, those reachable from
      # the initial_oriented_node. options[:leash_length] => max distance explored,
      # can be set to nil to search indefinitely.
      #
      # Returns a Hash of [node, first_side] => distance
      def min_distances(graph, initial_oriented_node, options={})
        pqueue = DS::AnyPriorityQueue.new {|a,b| a < b}
        first = DistancedOrientedNode.new
        first.node = initial_oriented_node.node
        first.first_side = initial_oriented_node.first_side
        first.distance = 0
        pqueue.push first, first.distance

        to_return = {}

        while min_distanced_node = pqueue.shift

          # Add/overwrite the current one
          to_return[min_distanced_node.to_settable] = min_distanced_node.distance

          log.debug "Working from #{min_distanced_node.inspect}"

          if options[:leash_length] and min_distanced_node.distance > options[:leash_length]
            # we are passed leash length, and this is the nearest node. So we are finito.
            break
          end

          # Queue nodes after this one
          current_distance = min_distanced_node.distance
          min_distanced_node.next_neighbours(graph).each do |onode|
            new_distance = current_distance+onode.node.length_alone
            log.debug "New distance for neighbour: #{onode}: #{new_distance}"
            if to_return[onode.to_settable] and to_return[onode.to_settable] < new_distance
              # We already know a shorter path to this neighbour, so ignore it
            else
              # new shortest distance found. queue it up
              distanced_node = DistancedOrientedNode.new
              distanced_node.node = onode.node
              distanced_node.first_side = onode.first_side
              distanced_node.distance = new_distance
              pqueue.push distanced_node, new_distance
            end
          end
        end
        return to_return
      end

      # An oriented node some distance from the origin of exploration
      class DistancedOrientedNode
        attr_accessor :node, :first_side, :distance

        # Using Set object, often we want two separate objects to be considered equal even if
        # they are distinct objects
        def to_settable
          [@node.node_id, @first_side]
        end

        # Which side of the node is not first?
        def second_side
          @first_side == OrientedNodeTrail::START_IS_FIRST ?
            OrientedNodeTrail::END_IS_FIRST :
            OrientedNodeTrail::START_IS_FIRST
        end

        def next_neighbours(graph)
          onode = Bio::Velvet::Graph::OrientedNodeTrail::OrientedNode.new
          onode.node = @node
          onode.first_side = @first_side
          return onode.next_neighbours(graph)
        end
      end
    end
  end
end
