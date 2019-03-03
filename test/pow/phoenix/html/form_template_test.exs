defmodule Pow.Phoenix.HTML.FormTemplateTest do
  use ExUnit.Case
  doctest Pow.Phoenix.HTML.FormTemplate

  alias Pow.Phoenix.HTML.FormTemplate

  test "render/2 with minimalist" do
    html = FormTemplate.render([
      {:text, {:changeset, :pow_user_id_field}},
      {:password, :password},
      {:password, :confirm_password}
    ])

    refute html =~ "<div class=\"form-group\">"
    assert html =~ "<%= label f, :password %>"
    assert html =~ "<%= password_input f, :password %>"
    assert html =~ "<%= error_tag f, :password %>"
  end
end
