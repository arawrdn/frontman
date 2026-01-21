defmodule FrontmanServerWeb.ModelsController do
  @moduledoc """
  Returns available LLM models grouped by provider.

  This is a static configuration endpoint - models are defined here
  and served to the frontend for the model selector dropdown.
  """
  use FrontmanServerWeb, :controller

  @default_model %{
    provider: "openrouter",
    value: "google/gemini-3-flash-preview"
  }

  @models_config %{
    providers: [
      %{
        id: "openrouter",
        name: "OpenRouter",
        models: [
          # OpenAI models
          %{displayName: "GPT-5.2", value: "openai/gpt-5.2"},
          %{displayName: "GPT-5.1", value: "openai/gpt-5.1"},
          %{displayName: "GPT-5", value: "openai/gpt-5"},
          %{displayName: "GPT-5 mini", value: "openai/gpt-5-mini"},
          %{displayName: "GPT-5 Chat", value: "openai/gpt-5-chat"},
          %{displayName: "GPT-4.1", value: "openai/gpt-4.1"},
          %{displayName: "o3", value: "openai/o3"},
          %{displayName: "o4-mini", value: "openai/o4-mini"},
          # Anthropic models
          %{displayName: "Claude Sonnet 4.5", value: "anthropic/claude-sonnet-4.5"},
          %{displayName: "Claude Opus 4.5", value: "anthropic/claude-opus-4.5"},
          %{displayName: "Claude Haiku 4.5", value: "anthropic/claude-haiku-4.5"},
          # Google models
          %{displayName: "Gemini 3 Pro Preview", value: "google/gemini-3-pro-preview"},
          %{displayName: "Gemini 3 Flash Preview", value: "google/gemini-3-flash-preview"},
          %{displayName: "Gemini 2.5 Pro", value: "google/gemini-2.5-pro"}
        ]
      }
    ],
    defaultModel: @default_model
  }

  @doc """
  Returns the available models configuration.

  GET /api/models

  Response:
  {
    "providers": [...],
    "defaultModel": {"provider": "openrouter", "value": "google/gemini-3-flash-preview"}
  }
  """
  def index(conn, _params) do
    json(conn, @models_config)
  end
end
