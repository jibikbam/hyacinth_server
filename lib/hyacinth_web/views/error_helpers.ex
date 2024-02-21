defmodule HyacinthWeb.ErrorHelpers do
  @moduledoc """
  Conveniences for translating and building error messages.
  """

  use Phoenix.HTML

  @doc """
  Generates tag for inlined form input errors.

  Options:

    * `:always_show_errors` - If true, errors will be shown
    even if a user has not yet modified the field.
    * `:name` - A name to use in place of the field name.

  ## Examples

      iex> error_tag(some_form, :some_field)
      iex> error_tag(some_form, :some_field, always_show_errors: true)
      iex> error_tag(some_form, :some_field, name: "MyField")

  """
  @spec error_tag(%Phoenix.HTML.Form{}, atom, keyword) :: any
  def error_tag(form, field, opts \\ []) when is_list(opts) do
    Enum.map(Keyword.get_values(form.errors, field), fn error ->
      content_tag(:span, humanize_error(field, opts[:name], error),
        class: "invalid-feedback",
        phx_feedback_for: unless(opts[:always_show_errors], do: input_name(form, field))
      )
    end)
  end

  @spec humanize_error(atom, String.t | nil, {String.t, keyword}) :: String.t
  defp humanize_error(field, name, error) do
    name = name || Phoenix.HTML.Form.humanize(field)
    name <> " " <> translate_error(error)
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate "is invalid" in the "errors" domain
    #     dgettext("errors", "is invalid")
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # Because the error messages we show in our forms and APIs
    # are defined inside Ecto, we need to translate them dynamically.
    # This requires us to call the Gettext module passing our gettext
    # backend as first argument.
    #
    # Note we use the "errors" domain, which means translations
    # should be written to the errors.po file. The :count option is
    # set by Ecto and indicates we should also apply plural rules.
    if count = opts[:count] do
      Gettext.dngettext(HyacinthWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(HyacinthWeb.Gettext, "errors", msg, opts)
    end
  end
end
