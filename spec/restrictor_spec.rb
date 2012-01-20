require File.join(File.expand_path(File.dirname(__FILE__)), 'setup')

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
      scrub_all
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
      scrub_all
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
      scrub_all
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
      scrub_all
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
          :type => :full
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
      scrub_all
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

  #!!! Stacked full restrictions
  describe 'when full permission and full group restrictors are applied' do
    before do
      Fubar.class_eval do
        add_restrictor(:permissions,
          :type => :full
        )
        add_restrictor(:groups,
          :type => :full
        )
      end
      4.times do |i|
        perm = Permission.find_by_name("permission_#{i}")
        user = User.find_by_username("user_#{i}")
        group = Group.find_by_name("group_#{i}")
        fubar = Fubar.find_by_name("fubar_#{i}")
        if(i % 2 == 0 || i == 3)
          user.permissions << perm
          fubar.permissions << perm
        end
        if(i % 2 == 1 || i == 3)
          user.groups << group
          fubar.groups << group
        end
      end
    end
    after do
      scrub_all
    end

    it 'should be setup correctly' do
      3.times do |i|
        u = User.find_by_username("user_#{i}")
        if(u.groups.count > 0)
          assert_equal(1, u.groups.count)
          assert_equal(0, u.permissions.count)
        elsif(u.permissions.count > 0)
          assert_equal(1, u.permissions.count)
          assert_equal(0, u.groups.count)
        else
          flunk "User should have one group or one permission assigned"
        end
      end
      assert_equal 1, User.find_by_username('user_3').groups.count
      assert_equal 1, User.find_by_username('user_3').permissions.count
      assert_equal 0, User.find_by_username('user_4').groups.count
      assert_equal 0, User.find_by_username('user_5').permissions.count
    end
    it 'should allow not allow users with single matching permission or group only' do
      3.times do |i|
        user = User.find_by_username("user_#{i}")
        assert_equal(0, user.allowed_fubars.count)
      end
    end
    it 'should allow users with both matching permission and group' do
      assert_equal(1, User.find_by_username('user_3').allowed_fubars.count)
    end
    it 'should not allow users with no matching permission or group' do
      assert_equal(0, User.find_by_username('user_4').allowed_fubars.count)
    end
  end

  describe 'when full permission and full group restrictors are applied using default_view_all' do
    before do
      Fubar.class_eval do
        add_restrictor(:permissions,
          :type => :full,
          :default_view_all => true
        )
        add_restrictor(:groups,
          :type => :full,
          :default_view_all => true
        )
      end
      4.times do |i|
        perm = Permission.find_by_name("permission_#{i}")
        user = User.find_by_username("user_#{i}")
        group = Group.find_by_name("group_#{i}")
        fubar = Fubar.find_by_name("fubar_#{i}")
        if(i % 2 == 0 || i == 3)
          user.permissions << perm
          fubar.permissions << perm
        end
        if(i % 2 == 1 || i == 3)
          user.groups << group
          fubar.groups << group
        end
      end
    end
    after do
      scrub_all
    end

    it 'should only provide fubars without assigned groups and permissions to users without assigned groups and permissions' do
      User.includes(:groups, :permissions).where(:groups => {:id => nil}, :permissions => {:id => nil}).each do |user|
        assert_equal(6, user.allowed_fubars.count)
        user.allowed_fubars.each do |fubar|
          assert_equal(0, fubar.groups.count)
          assert_equal(0, fubar.permissions.count)
        end
        assert_equal(0, user.groups.count)
        assert_equal(0, user.permissions.count)
      end
    end
    it 'should provide fubars with with matching group or permissions and fubars without assigned groups or permissions' do
      4.times do |i|
        user = User.find_by_username("user_#{i}")
        assert_equal(7, user.allowed_fubars.count)
        user.allowed_fubars.each do |fubar|
          if(fubar.groups.count > 0)
            assert_equal fubar.groups.first, user.groups.first
          end
          if(fubar.permissions.count > 0)
            assert_equal fubar.permissions.first, user.permissions.first
          end
        end
      end
    end
    it 'should allow all users when no permission and groups are defined' do
      6.times do |i|
        fubar = Fubar.find_by_name("fubar_#{i + 4}")
        assert_equal(10, fubar.allowed_users.count)
      end
    end
    it 'should only allow users with matching permission or group' do
      4.times do |i|
        fubar = Fubar.find_by_name("fubar_#{i}")
        assert_equal(1, fubar.allowed_users.count)
      end
    end
  end

  #!!! Stacked mixed restrictions
  describe 'when basic and full restrictors are applied' do
    before do
      Fubar.class_eval do
        add_restrictor(:enabled,
          :type => :basic_user,
          :scope => User.where(:active => true)
        )
        add_restrictor(:enabled,
          :type => :basic_model,
          :scope => where(:enabled => true)
        )
        add_restrictor(:permissions,
          :type => :full
        )
      end
      4.times do |i|
        user = User.find_by_username("user_#{i}")
        perm = Permission.find_by_name("permission_#{i}")
        fubar = Fubar.find_by_name("fubar_#{i}")
        user.permissions << perm
        fubar.permissions << perm
      end
    end
    after do
      scrub_all
    end

    it "should have disabled and enabled users and fubars setup" do
      users = 4.times.map{|i| User.find_by_username("user_#{i}")}
      fubars = 4.times.map{|i| Fubar.find_by_name("fubar_#{i}")}
      assert users.detect(&:active?), 'Expecting active users'
      assert users.detect{|u| !u.active?}, 'Expecting inactive users'
      assert fubars.detect(&:enabled?), 'Expecting enabled fubars'
      assert fubars.detect{|f| !f.enabled?}, 'Expecting disabled fubars'
    end
    it "should not show any allowed users when fubar is disabled" do
      fubar = Fubar.where(:name => 4.times.map{|i|"fubar_#{i}"}, :enabled => false).first
      assert fubar, "Expecting Fubar instance to be found"
      assert_equal 0, fubar.allowed_users.count
    end
    it "should only show active users when fubar is enabled" do
      fubar = Fubar.where(:name => 4.times.map{|i|"fubar_#{i}"}, :enabled => true).first
      assert fubar, "Expecting Fubar instance to be found"
      assert fubar.allowed_users.count > 0, 'Expecting allowed users to be found'
      fubar.allowed_users.each do |user|
        assert user.active?, 'Expecting user to be active'
      end
    end
    it "should not show any allowed fubars when user is inactive" do
      user = User.where(:username => 4.times.map{|i|"user_#{i}"}, :active => false).first
      assert user, "Expecting User instance to be found"
      assert_equal(0, user.allowed_fubars.count)
    end
    it "should only show enabled fubars when user is active" do
      user = User.where(:username => 4.times.map{|i|"user_#{i}"}, :active => true).first
      assert user, "Expecting User instance to be found"
      assert user.allowed_fubars.count > 0, 'Expecting allowed fubars to be found'
      user.allowed_fubars.each do |fubar|
        assert fubar.enabled?, 'Expecting fubar to be enabled'
      end
    end
    it "should only show enabled fubars with same permission as user" do
      User.where(:username => 4.times.map{|i|"user_#{i}"}, :active => true).all.each do |user|
        assert user.active?, 'Expecting active user'
        assert user.allowed_fubars.count > 0, 'Expecting user to have allowed fubars'
        user.allowed_fubars.each do |fubar|
          assert fubar.enabled?, 'Expecting Fubar to be enabled'
          assert_equal fubar.permissions.first, user.permissions.first
        end
      end
    end
  end

  # TODO: model_custom / user_custom
  # TODO: more complex stacking
end
