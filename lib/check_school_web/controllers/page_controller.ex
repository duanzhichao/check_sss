defmodule CheckSchoolWeb.PageController do
  use CheckSchoolWeb, :controller
  alias Elixlsx.Sheet
  alias Elixlsx.Workbook

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end

  def upload_yaml(conn, %{"file" => file_params}) do
    time = Timex.now("Asia/Shanghai")
      |> Timex.format!("{YYYY}{0M}{0D}{h24}{m}{s}")

    file_info = upload(file_params, "#{time}.xlsx")

    json(conn, %{msg: "", data: file_info.file_name, is_success: true})
  end

  def download_yaml(conn, %{"file_name" => file_name}) do
    case read_file(file_name) do
      :error ->
        json conn, %{a: "下载失败"}
      file ->
        %{:file_data => file_data, :file_name => file_name} = file
        conn
        |> put_resp_header("content-disposition", "attachment; filename=\"#{file_name}\"")
        |> send_resp(200, file_data)
    end
  end

  def convert(conn, %{"baokaofile" => baokaofile, "toudangfile" => toudangfile, "fen" => fen}) do
    fen = String.to_integer("#{fen}")

    bao = Path.join(System.tmp_dir!, baokaofile)
      |> read()
      |> elem(1)
      |> Enum.map(fn [_, xuexiao_number, xuexiao_name, zhuanye_number, zhuanye_name] ->
        %{xuexiao_number: to_string(xuexiao_number), xuexiao_name: xuexiao_name, zhuanye_number: to_string(zhuanye_number), zhuanye_name: zhuanye_name}
      end)

    bao_xuexiaos = Enum.map(bao, fn x -> x.xuexiao_number end)
    bao_zhuanyes = Enum.map(bao, fn x -> x.zhuanye_number end)

    result = Path.join(System.tmp_dir!, toudangfile)
      |> read()
      |> elem(1)
      |> Enum.map(fn [xuexiao_number, xuexiao_name, zhuanye_number, zhuanye_name, fen] ->
        %{xuexiao_number: to_string(xuexiao_number), xuexiao_name: xuexiao_name, zhuanye_number: to_string(zhuanye_number), zhuanye_name: zhuanye_name, fen: String.to_integer("#{fen}")}
      end)
      |> Enum.filter(fn x -> x.fen <= fen end)
      |> Enum.filter(fn x -> x.xuexiao_number in bao_xuexiaos end)
      |> Enum.filter(fn x -> x.zhuanye_number in bao_zhuanyes end)
      |> Enum.sort(&(&1.fen > &2.fen))
      |> Enum.map(fn x ->
        [x.xuexiao_number, x.xuexiao_name, x.zhuanye_number, x.zhuanye_name, x.fen]
      end)

    result = [["学校代码", "学校名称", "专业代码", "专业名称", "投档线"]] ++ result
    file_name = "可能能录取的学校_#{fen}分.xlsx"
    write(result, [System.tmp_dir(), file_name])
    json(conn, %{is_success: true, path: "download_yaml?file_name=#{file_name}"})
  end

  def write(data, file_path) do
    #生产文件路径
    file_path = List.flatten([file_path])
      |> Path.join()

    #求得文件目录
    dir_path = Path.dirname(file_path)
    #文件夹是否存在
    repair_dir(dir_path)

    #生成 Excel 数据
    sheets = cond do
        is_nil(data) ->
          []

        is_list(data) and hd(data) |> is_tuple() ->
          [data]

        is_tuple(data) ->
          [data]

        is_list(data) and hd(data) |> is_list() ->
          [{"sheet 1", data}]
      end
      |> List.flatten
      |> Enum.reject(fn {_, rows} -> is_nil(rows) end)
      |> Enum.map(fn {name, rows} -> %Sheet{name: name, rows: rows} end)

    workbook = %Workbook{sheets: sheets}
    #写入xlsx文件数据
    Elixlsx.write_to(workbook, file_path)
    #返回信息详情
    file_info(file_path)
  end

  def read(file_path) do
    case Path.extname(file_path) do
      ".xlsx" ->
        case File.read(file_path) do
          {:ok, _fileStr} ->
            data = Xlsxir.multi_extract(file_path)
              |> Enum.filter(fn {state, _} -> state == :ok end)
              |> Enum.map(fn {_, table_id} -> Xlsxir.get_list(table_id) end)
            cond do
              data == [] ->
                {:error, "文件记录为空"}
              is_map(List.first(data)) ->
                {:ok, List.first(data)}
              true ->
                {:ok, List.first(data)}
            end
          _ ->
            {:error, "文件不存在"}
        end
      _ ->
        {:error, "文件类型错误,应为xlsx格式"}
    end
  end

  defp read_file(file_name) do
    dir_path = System.tmp_dir()
    file_path = Path.join(dir_path, file_name)

    case File.read(file_path) do
      {:ok, file_data} ->
        %{file_data: file_data, file_name: file_name, extname: Path.extname(file_path)}
      {:error, _} ->
        :error
    end
  end

  #修补DIR目录
  defp repair_dir(dir_path) do
    # Path.dirname(dir_path)
    #文件夹是否存在
    with false <- dir_path |> File.exists? do
      File.mkdir_p(dir_path)
    end
  end

  @doc """
  文件上传功能
  """
  def upload(file_params, new_file_name \\ "") do
    file_path = Path.join("#{System.tmp_dir()}", new_file_name)
    %{:path => tmp_path} = file_params
    File.cp(tmp_path, file_path)
    file_info(file_path)
  end

  def file_info(file_path) do
    file_name = Path.basename(file_path)
    dir_path = Path.dirname(file_path)
    #读取文件信息
    case File.stat(file_path) do
      {:ok, result} ->
        %{
          file_path: file_path, #文件完整路径
          dir: dir_path, #文件存放路径
          size: result.size, #文件大小
          file_name: file_name
        }
      {:error, _} ->
        %{
          file_path: file_path, #文件完整路径
          dir: dir_path, #文件存放路径
          size: 0, #文件大小
          file_name: file_name
        }
    end
  end

end
