local vecmath = {}

function vecmath.length(x, y)
  return math.sqrt(x*x + y*y)
end

function vecmath.length2(x, y)
  return x*x + y*y
end

function vecmath.normalize(x, y)
  local length = vecmath.length(x, y)

  if length == 0 then
    return 0, 0
  end

  return x / length, y / length
end

function vecmath.dot(ax, ay, bx, by)
  return ax * bx + ay * by
end

function vecmath.scale(x, y, s)
  return x * s, y * s
end

function vecmath.lerp(x1, y1, x2, y2, t)
  return x1 + (x2 - x1) * t, y1 + (y2 - y1) * t
end

return vecmath
