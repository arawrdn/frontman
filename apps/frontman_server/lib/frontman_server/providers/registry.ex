defmodule FrontmanServer.Providers.Registry do
  @moduledoc """
  Centralised provider registry.

  Every supported provider is declared exactly once in `@providers`.
  Adding a new provider means adding a single entry here instead of
  touching 10+ files.

  ## Fields per provider

    * `:config_key` – the `Application.get_env(:frontman_server, key)` atom
      used to fetch the server-side API key from runtime config.
    * `:env_key_name` – the metadata key the client sends when forwarding a
      project-level API key (e.g. `"openrouterKeyValue"`).  `nil` means the
      client never sends a key for this provider.
    * `:display_name` – human-readable label shown in the UI.
    * `:priority` – integer for display ordering (lower = shown first).
    * `:oauth_provider` – the provider string used for OAuth token lookup.
      Usually matches the provider id, but `"openai"` uses `"chatgpt"`.
      `nil` means OAuth is not available.
    * `:env_key_param` – the query parameter name the client sends to signal
      it has a project-level env key for this provider. `nil` if not applicable.
  """

  @type provider_entry :: %{
          config_key: atom(),
          env_key_name: String.t() | nil,
          display_name: String.t(),
          priority: non_neg_integer(),
          oauth_provider: String.t() | nil,
          env_key_param: String.t() | nil
        }

  @providers %{
    "openai" => %{
      config_key: :openai_api_key,
      env_key_name: nil,
      display_name: "ChatGPT Pro/Plus",
      priority: 10,
      oauth_provider: "chatgpt",
      env_key_param: nil
    },
    "anthropic" => %{
      config_key: :anthropic_api_key,
      env_key_name: "anthropicKeyValue",
      display_name: "Anthropic (Claude Pro/Max)",
      priority: 20,
      oauth_provider: "anthropic",
      env_key_param: "hasAnthropicEnvKey"
    },
    "openrouter" => %{
      config_key: :openrouter_api_key,
      env_key_name: "openrouterKeyValue",
      display_name: "OpenRouter",
      priority: 30,
      oauth_provider: nil,
      env_key_param: "hasEnvKey"
    },
    "google" => %{
      config_key: :google_api_key,
      env_key_name: nil,
      display_name: "Google",
      priority: 40,
      oauth_provider: nil,
      env_key_param: nil
    },
    "xai" => %{
      config_key: :xai_api_key,
      env_key_name: nil,
      display_name: "xAI",
      priority: 50,
      oauth_provider: nil,
      env_key_param: nil
    }
  }

  @doc """
  Returns the full provider map.  Mostly useful for enumeration / debugging.
  """
  @spec all() :: %{String.t() => provider_entry()}
  def all, do: @providers

  @doc """
  Returns `true` if the provider string is known to the registry.
  """
  @spec known?(String.t()) :: boolean()
  def known?(provider) when is_binary(provider) do
    Map.has_key?(@providers, String.downcase(provider))
  end

  # ── Field accessors ─────────────────────────────────────────────────

  @doc """
  Returns the `Application.get_env` config key atom for the given provider,
  or `nil` if the provider is unknown.

  ## Examples

      iex> Registry.config_key("openrouter")
      :openrouter_api_key

      iex> Registry.config_key("unknown")
      nil
  """
  @spec config_key(String.t()) :: atom() | nil
  def config_key(provider) when is_binary(provider) do
    get_field(provider, :config_key)
  end

  @doc """
  Returns the human-readable display name for a provider, or `nil`.
  """
  @spec display_name(String.t()) :: String.t() | nil
  def display_name(provider) when is_binary(provider) do
    get_field(provider, :display_name)
  end

  @doc """
  Returns the OAuth provider string used for token lookup, or `nil` when
  OAuth is not available for this provider.

  Most providers use their own id, but `"openai"` stores tokens as `"chatgpt"`.
  """
  @spec oauth_provider(String.t()) :: String.t() | nil
  def oauth_provider(provider) when is_binary(provider) do
    get_field(provider, :oauth_provider)
  end

  @doc """
  Returns the query parameter name the client sends to indicate it has an
  env key for this provider, or `nil` when not applicable.
  """
  @spec env_key_param(String.t()) :: String.t() | nil
  def env_key_param(provider) when is_binary(provider) do
    get_field(provider, :env_key_param)
  end

  @doc """
  Returns the display priority for a provider (lower = shown first), or `nil`.
  """
  @spec priority(String.t()) :: non_neg_integer() | nil
  def priority(provider) when is_binary(provider) do
    get_field(provider, :priority)
  end

  # ── Env key helpers ────────────────────────────────────────────────

  @doc """
  Returns a map of `%{env_key_name => provider}` for providers that accept
  client-forwarded keys.

  Used internally by `extract_env_keys/1` but also useful for testing.

  ## Examples

      iex> Registry.env_key_mapping()
      %{"openrouterKeyValue" => "openrouter", "anthropicKeyValue" => "anthropic"}
  """
  @spec env_key_mapping() :: %{String.t() => String.t()}
  def env_key_mapping do
    for {provider, %{env_key_name: name}} when is_binary(name) <- @providers,
        into: %{} do
      {name, provider}
    end
  end

  @doc """
  Extracts provider API keys from a metadata map sent by the client.

  This replaces the duplicated `extract_env_api_key*` functions in both
  `TaskChannel` and `TasksChannel`.

  ## Parameters

    * `metadata` – the metadata map from client params.  Keys like
      `"openrouterKeyValue"` are mapped to their provider name.

  ## Returns

  A map of `%{provider => api_key}` for every key present and non-empty.

  ## Examples

      iex> Registry.extract_env_keys(%{"openrouterKeyValue" => "sk-or-123"})
      %{"openrouter" => "sk-or-123"}

      iex> Registry.extract_env_keys(%{})
      %{}
  """
  @spec extract_env_keys(map()) :: %{String.t() => String.t()}
  def extract_env_keys(metadata) when is_map(metadata) do
    for {meta_key, provider} <- env_key_mapping(),
        key = metadata[meta_key],
        is_binary(key) and key != "",
        into: %{} do
      {provider, key}
    end
  end

  def extract_env_keys(_), do: %{}

  # ── Server key lookup ──────────────────────────────────────────────

  @doc """
  Fetches the server API key for a provider from application config.

  ## Examples

      iex> Registry.get_server_api_key("openrouter")
      # value from Application.get_env(:frontman_server, :openrouter_api_key)
  """
  @spec get_server_api_key(String.t()) :: String.t() | nil
  def get_server_api_key(provider) when is_binary(provider) do
    case config_key(provider) do
      nil -> nil
      key -> Application.get_env(:frontman_server, key)
    end
  end

  # ── Private ────────────────────────────────────────────────────────

  defp get_field(provider, field) do
    case Map.get(@providers, String.downcase(provider)) do
      %{} = entry -> Map.get(entry, field)
      nil -> nil
    end
  end
end
