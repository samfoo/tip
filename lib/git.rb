require 'rugged'
require 'tmpdir'
require 'json'

class Reference
  def self.name
    "tips/meta"
  end
end

class Vote
  def self.up! repo, *paths
    details = JSON.generate(paths.inject({}) do |m, p|
      m.merge({p => 1})
    end)

    create_commit! repo, details
  end

  def self.down! repo, *paths
    details = JSON.generate(paths.inject({}) do |m, p|
      m.merge({p => -1})
    end)

    create_commit! repo, details
  end

  def self.list repo
    iter = Rugged::Walker.new repo
    iter.push repo.references[Reference.name].target.oid
    iter.inject({}) do |results, commit|
      c = JSON.parse(commit.message)

      c.inject(results) do |m, (k, v)|
        m.merge({k => m[k].to_i + v})
      end
    end
  end

  def self.create_commit! repo, json
    index = Rugged::Index.new
    tree = index.write_tree(repo)

    details = {
      author: {
        email: "tips@for.good.code",
        time: Time.now,
        name: "Tips"
      },
      parents: [repo.references[Reference.name].target_id],
      tree: tree,
      message: json,
      update_ref: Reference.name
    }

    commit = Rugged::Commit.create(repo, details)
  end
end

class Repository
  def self.maybe_create_reference! repo, name
    index = repo.index
    index.remove_all
    tree = index.write_tree(repo)

    details = {
      author: {
        email: "tips@for.good.code",
        time: Time.now,
        name: "Tips"
      },
      parents: [],
      tree: tree,
      message: "{}"
    }

    begin
      commit = Rugged::Commit.create(repo, details)
      repo.references.create(Reference.name, commit)
    rescue Rugged::ReferenceError
    end
  end

  def self.at uri, &block
    repo = Rugged::Repository.discover uri

    maybe_create_reference! repo, Reference.name

    block.call repo
  end
end
