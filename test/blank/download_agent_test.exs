defmodule Blank.DownloadAgentTest do
  use ExUnit.Case

  setup do
    dir =
      Path.join(
        System.tmp_dir!(),
        "blank_download_agent_test_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)

    on_exit(fn ->
      File.rm_rf(dir)
    end)

    %{tmp_dir: dir}
  end

  test "add/3 then get/1 returns the path", %{tmp_dir: dir} do
    path = Path.join(dir, "file.txt")
    File.touch!(path)
    id = "test-#{System.unique_integer([:positive])}"

    assert {:ok, ^id} = Blank.DownloadAgent.add(id, path)
    assert {:ok, ^path} = Blank.DownloadAgent.get(id)
  end

  test "get/1 returns error for unknown id" do
    assert {:error, "download does not exist"} =
             Blank.DownloadAgent.get("nonexistent-#{System.unique_integer([:positive])}")
  end

  test "delete/1 removes the file and entry", %{tmp_dir: dir} do
    path = Path.join(dir, "to_delete.txt")
    File.touch!(path)
    id = "del-#{System.unique_integer([:positive])}"

    Blank.DownloadAgent.add(id, path)
    assert File.exists?(path)

    Blank.DownloadAgent.delete(id)
    # delete is a cast, so give it a moment
    Process.sleep(50)

    assert {:error, "download does not exist"} = Blank.DownloadAgent.get(id)
    refute File.exists?(path)
  end

  test "add/3 with TTL expires entries", %{tmp_dir: dir} do
    path = Path.join(dir, "ttl_file.txt")
    File.touch!(path)
    id = "ttl-#{System.unique_integer([:positive])}"

    Blank.DownloadAgent.add(id, path, 10)
    assert {:ok, ^path} = Blank.DownloadAgent.get(id)

    Process.sleep(50)

    assert {:error, "download does not exist"} = Blank.DownloadAgent.get(id)
  end

  test "get/1 returns error if the file no longer exists on disk", %{tmp_dir: dir} do
    path = Path.join(dir, "removed.txt")
    File.touch!(path)
    id = "rm-#{System.unique_integer([:positive])}"

    Blank.DownloadAgent.add(id, path)
    assert {:ok, ^path} = Blank.DownloadAgent.get(id)

    File.rm!(path)

    assert {:error, "download does not exist"} = Blank.DownloadAgent.get(id)
  end
end
