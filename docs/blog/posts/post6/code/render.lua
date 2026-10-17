-- Two ordinary filter passes avoid a nested document walk.
local values = nil
local function compute(meta)
  local root = pandoc.path.directory(quarto.doc.input_file)
  local script = pandoc.path.join({root, 'code', '02_render.py'})
  local python = os.getenv('BLOG6_PYTHON')
  if not python then
    local conda = (os.getenv('USERPROFILE') or '') .. '/anaconda3/python.exe'
    local handle = io.open(conda, 'rb')
    if handle then
      handle:close()
      python = conda
    else
      python = os.getenv('WINDIR') and 'python' or 'python3'
    end
  end
  local ok, output = pcall(pandoc.pipe, python, {'-X', 'utf8', script}, '')
  if not ok then
    error('Blog6 Python analysis failed. Check the interpreter and code/requirements.txt.\n' .. tostring(output))
  end
  values = quarto.json.decode(output)
  return meta
end
local function insert_result(el)
  el.text = el.text:gsub('{{([%w_]+)}}', function(key)
    if not values or values[key] == nil then error('Unknown Blog6 result: ' .. key) end
    return tostring(values[key])
  end)
  return el
end
return {{Meta = compute}, {Str = insert_result}}
