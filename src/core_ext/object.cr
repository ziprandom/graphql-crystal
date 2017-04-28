class Object
  def debug
    pp self
  end

  def with_self
    with self yield
  end
end
