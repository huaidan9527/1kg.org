# == Schema Information
# Schema version: 20090430155946
#
# Table name: school_contacts
#
#  id                  :integer         not null, primary key
#  school_id           :integer
#  name                :string(255)
#  role                :string(255)
#  telephone           :string(255)
#  email               :string(255)
#  qq                  :string(255)
#  last_modified_at    :datetime
#  last_modified_by_id :integer
#

class SchoolContact < ActiveRecord::Base
  belongs_to :school
end
