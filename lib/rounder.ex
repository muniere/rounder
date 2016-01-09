defmodule Rounder.Release do

  defstruct repo: nil, date: nil, tag: nil

  @doc """
  Filter only release objects
  """
  @spec filter(Enumerable.t) :: Enumerable.t
  def filter(collection) do
    collection |> Enum.filter(fn(x) -> x.__struct__ == Rounder.Release end)
  end

  @doc """
  Sort releases as they are
  """
  @spec sort(Enumerable.t, nil) :: Enumerable.t
  def sort(releases, nil) do
    releases
  end

  @doc """
  Sort releases by given field
  """
  @spec sort(Enumerable.t, String.t) :: Enumerable.t
  def sort(releases, field) when is_binary(field) do
    sort(releases, String.to_atom(field))
  end

  @doc """
  Sort releases by given field
  """
  @spec sort(Enumerable.t, atom) :: Enumerable.t
  def sort(releases, field) when is_atom(field) do
    case field do
      :repo -> releases |> Enum.sort(&(&1.repo <= &2.repo))
      :tag  -> releases |> Enum.sort(&(&1.tag  <= &2.repo))
      :date -> releases |> Enum.sort(&(Timex.Date.to_secs(&1.date) >= Timex.Date.to_secs(&2.date)))
      _     -> releases
    end
  end

  @doc """
  Format releases into string
  """
  @spec format([]) :: String.t
  def format([]) do
    nil
  end

  @doc """
  Format releases into string
  """
  @spec format(Enumerable.t) :: String.t
  def format(releases) do

    repo_w = releases |> Enum.map(fn(x) -> String.length(x.repo) end) |> Enum.max
    tag_w  = releases |> Enum.map(fn(x) -> String.length(x.tag) end)  |> Enum.max

    releases 
      |> Enum.map(fn(release) ->
        repo_s  = String.ljust(release.repo, repo_w)
        tag_s   = String.ljust(release.tag, tag_w)
        date_s  = release.date |> Timex.DateFormat.format!("%Y-%m-%d %H:%M:%S", :strftime)
        "#{repo_s} #{tag_s} (#{date_s})"
      end)
      |> Enum.join("\n")
  end

end

defmodule Rounder.Error do

  defstruct repo: nil, message: nil

  @doc """
  Filter only error objects
  """
  @spec filter(Enumerable.t) :: Enumerable.t
  def filter(collection) do
    collection |> Enum.filter(fn(x) -> x.__struct__ == Rounder.Error end)
  end

  @doc """
  Sort errors as they are
  """
  @spec sort(Enumerable.t, any) :: Enumerable.t
  def sort(errors, _) do
    errors
  end

  @doc """
  Format errors into string
  """
  @spec format([]) :: String.t
  def format([]) do
    nil
  end

  @doc """
  Format errors into string
  """
  @spec format(Enumerable.t) :: String.t
  def format(errors) do

    repo_w = errors |> Enum.map(fn(x) -> String.length(x.repo) end) |> Enum.max

    errors
      |> Enum.map(fn(error) ->
        repo_s = String.ljust(error.repo, repo_w)
        message_s = error.message

        "#{repo_s}: #{message_s}"
      end)
      |> Enum.join("\n")
  end

end

defmodule Rounder.Endpoint do

  @doc """
  Get URI of releases API 
  """
  @spec releases(Strint.t) :: URI.t
  def releases(repo) do
    repos(repo, "releases")
  end

  @doc """
  Get URI of tags API 
  """
  @spec tags(Strint.t) :: URI.t
  def tags(repo) do
    repos(repo, "tags")
  end

  @doc """
  Get URI of commits API 
  """
  @spec commits(String.t, Strint.t) :: URI.t
  def commits(repo, sha) do
    repos(repo, "git/commits/#{sha}")
  end

  @spec repos(String.t, String.t) :: URI.t
  defp repos(repo, extra) do
    %URI{
      scheme: "https",
      host:   "api.github.com",
      path:   Path.join(["/", "repos", repo, extra])
    }
  end
end

defmodule Rounder.Spider do

  require Logger
  require HTTPoison

  @doc """
  Fetch latest release or tag of repository
  """
  @spec fetch(String.t) :: Rounder.Release.t | Rounder.Error.t | nil
  def fetch(repo) do
    try do
      fetch_release_ex(repo) || fetch_tag_ex(repo)
    catch x ->
      x
    end
  end

  @spec fetch_release_ex(String.t) :: Rounder.Release.t | nil
  defp fetch_release_ex(repo) do
    release = fetch_release(repo)

    if is_map(release) do
      %Rounder.Release{
        repo:  repo,
        date:  release["published_at"] |> Timex.DateFormat.parse!("{ISOz}"),
        tag:   release["tag_name"],
      }
    else
      nil
    end
  end

  @spec fetch_tag_ex(String.t) :: Rounder.Release.t | nil
  defp fetch_tag_ex(repo) do
    tag = fetch_tag(repo)

    if is_map(tag) do
      commit = fetch_commit(repo, tag["commit"]["sha"])

      if is_map(commit) do
        %Rounder.Release{
          repo: repo,
          date: commit["committer"]["date"] |> Timex.DateFormat.parse!("{ISOz}"),
          tag:  tag["name"],
        }
      else
        nil
      end
    else
      nil
    end
  end

  @spec fetch_release(String.t) :: Map.t | nil
  defp fetch_release(repo) do
    uri_s = URI.to_string(Rounder.Endpoint.releases(repo))

    Logger.debug("Fetch contents of URI: #{uri_s}")

    case HTTPoison.get(uri_s) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} -> 
        body |> Poison.decode! |> List.first
      {_, res} ->
        handle(repo, res)
    end
  end

  @spec fetch_tag(String.t) :: Map.t | nil
  defp fetch_tag(repo) do
    uri_s = URI.to_string(Rounder.Endpoint.tags(repo))

    Logger.debug("Fetch contents of URI: #{uri_s}")

    case HTTPoison.get(uri_s) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} -> 
        body |> Poison.decode! |> List.first
      {_, res} ->
        handle(repo, res)
    end
  end

  @spec fetch_commit(String.t, String.t) :: Map.t | nil
  defp fetch_commit(repo, sha) do
    uri_s = URI.to_string(Rounder.Endpoint.commits(repo, sha))

    Logger.debug("Fetch contents of URI: #{uri_s}")

    case HTTPoison.get(uri_s) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} -> 
        body |> Poison.decode! 
      {_, res} ->
        handle(repo, res)
    end
  end

  defp handle(repo, res) do
    case res do
      %HTTPoison.Response{status_code: 401} -> 
       throw %Rounder.Error{ repo: repo, message: "Unauthorized" }
      %HTTPoison.Response{status_code: 403} -> 
       throw %Rounder.Error{ repo: repo, message: "Forbidden" }
      %HTTPoison.Response{status_code: 404} -> 
       throw %Rounder.Error{ repo: repo, message: "Page Not FOUND" }
      %HTTPoison.Response{status_code: 500} -> 
       throw %Rounder.Error{ repo: repo, message: "Internal Server Error" }
      %HTTPoison.Error{reason: reason} ->
       throw %Rounder.Error{ repo: repo, message: reason }
    end
  end
end

defmodule Rounder.CLI do

  def main(argv) do

    {opts, repos} = parse(argv)

    results = repos
                |> Enum.map(&Task.async(fn -> Rounder.Spider.fetch(&1) end))
                |> Enum.map(&Task.await/1)

    results 
      |> Rounder.Release.filter
      |> Rounder.Release.sort(opts[:sort])
      |> Rounder.Release.format
      |> Rounder.CLI.puts

    results 
      |> Rounder.Error.filter
      |> Rounder.Error.sort(opts[:sort])
      |> Rounder.Error.format
      |> Rounder.CLI.puts
  end

  def parse(argv) do
    {opts, args, _err} = OptionParser.parse(argv, 
      strict: [
        input:   :string,
        sort:    :string,
        verbose: :boolean,
        help:    :boolean,
      ],
      aliases: [
        i: :input,
        s: :sort,
        v: :verbose,
        h: :help,
      ]
    )

    if opts[:help] do
      IO.write(:stderr, usage)
      Kernel.exit({:shutdown, 0})
    end

    repos = if is_bitstring(opts[:input]) and String.length(opts[:input]) > 0 do
              args ++ File.read!(opts[:input]) 
                |> String.split(["\n", "\r\n"])
                |> Enum.reject(fn(x) -> Regex.match?(~r/^#|^\s*$/, x) end)
            else
              args
            end

    if Enum.empty?(repos) do
      IO.write(:stderr, usage)
      Kernel.exit({:shutdown, 1})
    end

    case opts[:verbose] do
      true  -> Logger.configure([level: :debug])
      _     -> Logger.configure([level: :warn])
    end

    {opts, repos}
  end

  def puts(x) do
    if x != nil and String.length(x) > 0 do
      IO.puts(x)
    end
  end

  def usage do
    ~s"""
    Usage: rounder [options] [<repository> ..]

      -i, --input=file  Path to input file with the list of repositories
      -s, --sort=field  Field to use for sort [repo|tag|date]
      -v, --verbose     Show verbose messages
      -h, --help        Show this help
    """
  end
end


defmodule Enumx do

  def compact(collection) do
    collection |> Enum.filter(fn(x) -> x != nil end)
  end

end

