$:.unshift(File.expand_path(File.dirname(__FILE__) + '/../lib'))
require 'rubygems'
require 'bundler/setup'
require 'active_record'
require 'sqlite3'
require 'active_restrictors'
require 'minitest/autorun'

AR_DB_STORE = File.join(File.dirname(__FILE__), '.active_restrictor_db.sqlite3')

if(File.exists?(AR_DB_STORE))
  File.delete AR_DB_STORE
end
ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => AR_DB_STORE
)
load File.join(File.expand_path(File.dirname(__FILE__)), 'model_definitions.rb')

describe ActiveRestrictor do
  # Check for proper setup at the start
  describe 'after suite setup' do
    it 'should have properly setup models' do
      assert_equal 10,  User.count
      assert_equal 10, Fubar.count
      assert_equal 5, Group.count
      assert_equal 5, Permission.count
      refute_equal User.count, User.where(:active => true).count
    end
  end


  #!!!! basic_user type restrictions
  describe 'when basic user restrictor only allows active users' do
    before do
      Fubar.class_eval do
        add_restrictor(:active,
          :type => :basic_user,
          :scope => User.where(:active => true)
        )
      end
    end
    after do
      Fubar.restrictors.clear
    end
    it 'should only allow active users access to fubars' do
      u = User.where(:active => true).first
      assert u.allowed_fubars.count > 0
      u = User.where(:active => false).first
      assert_equal 0, u.allowed_fubars.count
    end
    it 'should only show active users from fubars' do
      Fubar.all.each do |fubar|
        fubar.allowed_users.each do |user|
          assert user.active
        end
      end
    end
  end

  describe 'when basic user restrictor provide enabled block' do
    before do
      Fubar.class_eval do
        add_restrictor(:active,
          :type => :basic_user,
          :scope => User.where(:active => true),
          :enabled => lambda{ User.current_user.nil? || !User.current_user.username == 'user_1' }
        )
      end
      u = User.find_by_username('user_1')
      u.active = false
      u.save!
    end
    after do
      User.current_user = nil
      Fubar.restrictors.clear
    end
    it 'should not allow fubars for user_1 when current_user is unset' do
      assert_equal 0, User.find_by_username('user_1').allowed_fubars.count
    end
    it 'should allow fubars for user_1 when current_user is set' do
      u = User.find_by_username('user_1')
      User.current_user = u
      assert u.allowed_fubars.count > 0
    end
  end

  #!!! basic model type restrictions
  describe 'when basic model restrictor only allows enabled fubars' do
    before do
      Fubar.class_eval do
        add_restrictor(:enabled,
          :type => :basic_model,
          :scope => Fubar.where(:enabled => true)
        )
      end
    end
    after do
      Fubar.restrictors.clear
    end
    it 'should only allow users to access enabled fubars' do
      User.all.each do |user|
        user.allowed_fubars.each do |fubar|
          assert fubar.enabled?
        end
      end
    end
    it 'should not provide users from disabled fubars' do
      assert Fubar.where(:enabled => false).count > 0
      Fubar.where(:enabled => false).all.each do |fubar|
        assert_equal 0, fubar.allowed_users.count
      end
    end
  end

  #!!! implicit model type restrictions
  describe 'when implict restrictor only allows fubars belonging to users' do
    before do
      Fubar.class_eval do
        add_restrictor(:user,
          :type => :implicit,
          :scope => lambda{ where(:user_id => User.current_user.id) }
        )
      end
      u = User.find_by_username("user_1")
      3.times do |i|
        f = Fubar.find_by_name("fubar_#{i}")
        f.user_id = u.id
        f.save!
      end
      User.current_user = u
    end
    after do
      Fubar.restrictors.clear
      Fubar.all.each do |fubar|
        fubar.user_id = nil
        fubar.save!
      end
      Fubar.update_all('user_id = null')
      User.current_user = nil
    end
    it 'should show 3 fubars for user_1' do
      assert_equal 3, User.find_by_username('user_1').fubars.count
    end
    it 'should show no fubars for users not user_1' do
      User.where("username != 'user_1'").all.each do |user|
        assert_equal 0, user.fubars.count
      end
    end
    it 'should only show allowed users as assigned users' do
      Fubar.all.each do |fubar|
        if(fubar.user_id.nil?)
          assert_equal 0, fubar.allowed_users.count 
        else
          assert_equal 1, fubar.allowed_users.count
          assert_equal 'user_1', fubar.allowed_users.first.username
        end
      end
    end
  end

  #!!! full type restrictions
  describe 'when full permission restrictor is applied' do
    before do
      Fubar.class_eval do
        add_restrictor(:permissions,
          :type => :full,
          :views => {
            :value => :name
          }
        )
      end
      3.times do |i|
        perm = Permission.find_by_name("permission_#{i}")
        user = User.find_by_username("user_#{i}")
        fubar = Fubar.find_by_name("fubar_#{i}")
        user.permissions << perm
        fubar.permissions << perm
      end
    end
    after do
      Fubar.restrictors.clear
    end
    it 'should only allow users with matching permissions' do
      3.times do |i|
        user = User.find_by_username("user_#{i}")
        fubar = Fubar.find_by_name("fubar_#{i}")
        assert_equal 1, user.allowed_fubars.count
        assert_equal 1, fubar.allowed_users.count
        assert_equal "fubar_#{i}", user.allowed_fubars.first.name
        assert_equal "user_#{i}", fubar.allowed_users.first.username
      end
    end
    it 'should not allow users without matching permissions' do
      7.times do |i|
        i = i + 3
        user = User.find_by_username("user_#{i}")
        fubar = Fubar.find_by_name("fubar_#{i}")
        assert_equal 0, user.allowed_fubars.count
        assert_equal 0, fubar.allowed_users.count
      end
    end
  end

  # TODO: Add specs for restrictor stacking behavior

end
