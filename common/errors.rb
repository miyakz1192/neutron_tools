class ShowMustBeSingleUUID < StandardError
end

class NovaError < StandardError
end

class MultipleInstanceNameFound < NovaError
end
