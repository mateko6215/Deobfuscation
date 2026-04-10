local function fib(n)
  if n < 2 then
    return n
  end
  return fib(n - 1) + fib(n - 2)
end

local t = { title = 'demo', value = 7 }
for i = 1, 5 do
  t[i] = fib(i)
end

print(t.title, t.value)
print('fib(8)=', fib(8))
print('table[3]=', t[3])
