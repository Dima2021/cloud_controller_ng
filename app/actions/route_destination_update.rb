module VCAP::CloudController
  class RouteDestinationUpdate
    def self.update(destination, message)
      destination.db.transaction do
        destination.lock!

        destination.protocol = message.protocol if message.requested? :protocol

        destination.save
      end
    end
  end
end
