class Courseware::Dummy
  def method_missing(meth, *args, &block)
    raise "Cannot call #{meth} without a working courseware repository"
  end
end
