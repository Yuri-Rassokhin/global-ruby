
class World
  include Singleton

  # by default, the world landscape equals to localhost
  def initialize
    # The one and only set of all nodes in the world
    @@world = Set.new('127.0.0.1')
    # Those world nodes that are assigned names, for convenience
    @@nodes = {
      'localhost': '127.0.0.1'
    }
    # Methods that are landed onto a node, 1:N relation
    # Every method is associated with a group of nodes where it is landed on
    # When the method is invoked, it runs on all such nodes
    # Global Ruby assesses if it is safe to run the method on its nodes in parallel
    # If it safe, it marks the method's group as "parallelizable"
    # Otherwise, TODO
    # NOTE: it is unique opportunity of Global Ruby's approach to detect potential race conditions
    # ... and therefore decide where instances of a method can run in parallel or not
    @@methods = {}

    @@world_new = ( scan("10.0.0", 22, 50, "ubuntu") + scan("10.0.0", 22, 50, "opc") )
    puts @@world_new.inspect
  end

  # add a new node to the world landscape
  def add(url, name = nil)
    @@world << url
    @@nodes[url] = name if name
  end
end

