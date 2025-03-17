
class Backend
  def initialize
  end
  # Abstract class representing communication between landed chunks
  # This class must be overriden by specific communicators: SSH, HTTP, Object Storage, and so forth
end

