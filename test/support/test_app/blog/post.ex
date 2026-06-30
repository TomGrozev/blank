defmodule TestApp.Blog.Post do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {
    Blank.Schema,
    identity_field: :title,
    fields: [
      title: [searchable: true, sortable: true],
      body: [label: "Body"],
      published: [sortable: true],
      views: [sortable: true],
      author: [display_field: :name, searchable: true],
      tags: [children: [name: [label: "Tag Name"]]],
      comments: [children: [body: [label: "Comment"]]]
    ]
  }

  schema "test_app_posts" do
    field :title, :string
    field :body, :string
    field :published, :boolean, default: false
    field :views, :integer, default: 0
    field :published_at, :utc_datetime

    belongs_to :author, TestApp.Accounts.User
    has_many :tags, TestApp.Blog.Tag
    has_many :comments, TestApp.Blog.Comment

    timestamps()
  end

  def changeset(post, attrs) do
    post
    |> cast(attrs, [:title, :body, :published, :views, :published_at, :author_id])
    |> validate_required([:title])
  end
end
