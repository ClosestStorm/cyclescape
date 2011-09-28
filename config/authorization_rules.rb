authorization do
  role :admin do
    includes :member
    has_permission_on :groups, :group_members, :group_memberships, to: :manage
  end

  role :member do
    includes :guest
  end

  role :guest do
    has_permission_on :devise_sessions, to: :manage
  end
end

privileges do
  privilege :manage do
    includes :create, :read, :update, :delete
  end
end