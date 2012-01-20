
class ModelSetup < ActiveRecord::Migration
  def self.up
    create_table :users do |t|
      t.string :username
      t.boolean :active
    end
    create_table :fubars do |t|
      t.string :name
      t.boolean :enabled
      t.integer :user_id
    end
    create_table :permissions do |t|
      t.string :name
    end
    create_table :groups do |t|
      t.string :name
    end
    create_table :user_permissions do |t|
      t.integer :user_id
      t.integer :permission_id
    end
    create_table :fubar_permissions do |t|
      t.integer :fubar_id
      t.integer :permission_id
    end
    create_table :user_groups do |t|
      t.integer :group_id
      t.integer :user_id
    end
    create_table :fubar_groups do |t|
      t.integer :group_id
      t.integer :fubar_id
    end
  end
end

ModelSetup.up

class User < ActiveRecord::Base
  cattr_accessor :current_user
  has_many :user_permissions, :dependent => :destroy
  has_many :permissions, :through => :user_permissions
  has_many :user_groups, :dependent => :destroy
  has_many :groups, :through => :user_groups
  has_many :fubars, :dependent => :destroy
end

class Permission < ActiveRecord::Base
  has_many :user_permissions, :dependent => :destroy
  has_many :users, :through => :user_permissions
  has_many :fubar_permissions, :dependent => :destroy
  has_many :fubars, :through => :fubar_permissions
end

class Group < ActiveRecord::Base
  has_many :user_groups, :dependent => :destroy
  has_many :users, :through => :user_groups
  has_many :fubar_groups, :dependent => :destroy
  has_many :fubars, :through => :fubar_groups
end

class Fubar < ActiveRecord::Base
  include ActiveRestrictor
  has_many :fubar_permissions, :dependent => :destroy
  has_many :permissions, :through => :fubar_permissions
  has_many :fubar_groups, :dependent => :destroy
  has_many :groups, :through => :fubar_groups
  belongs_to :user
end

class UserPermission < ActiveRecord::Base
  belongs_to :user
  belongs_to :permission
end

class FubarPermission < ActiveRecord::Base
  belongs_to :fubar
  belongs_to :permission
end

class FubarGroup < ActiveRecord::Base
  belongs_to :fubar
  belongs_to :group
end

class UserGroup < ActiveRecord::Base
  belongs_to :user
  belongs_to :group
end

def scrub_all
  Fubar.restrictors.clear
  UserGroup.delete_all
  FubarGroup.delete_all
  UserPermission.delete_all
  FubarPermission.delete_all
  User.current_user = nil
  Fubar.update_all(:user_id => nil)
end

# Setup our test models
10.times do |i|
  User.create(:username => "user_#{i}", :active => i % 2 == 0)
  Fubar.create(:name => "fubar_#{i}", :enabled => i % 2 == 0)
end

5.times do |i|
  Permission.create(:name => "permission_#{i}")
end

5.times do |i|
  Group.create(:name => "group_#{i}")
end
