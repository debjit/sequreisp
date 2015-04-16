# Sequreisp - Copyright 2010, 2011 Luciano Ruete
#
# This file is part of Sequreisp.
#
# Sequreisp is free software: you can redistribute it and/or modify
# it under the terms of the GNU Afero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Sequreisp is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Afero General Public License for more details.
#
# You should have received a copy of the GNU Afero General Public License
# along with Sequreisp.  If not, see <http://www.gnu.org/licenses/>.

class Plan < ActiveRecord::Base
  has_many :contracts, :dependent => :destroy, :include => :klass
  has_many :providers, :through => :provider_group
  acts_as_audited
  belongs_to :provider_group

  attr_accessor :how_use_cir
  attr_accessor :cir_percentage
  attr_accessor_with_default :value_cir_re_used, "1:1"

  def after_initialize
    self.cir_percentage = self.cir_up if self.used_cir_percentage
    self.how_use_cir = default_value_for_which_use_cir if how_use_cir.nil?
  end

  def default_value_for_which_use_cir
    return "total_cir" if self.used_total_cir
    return "percentage" if self.used_cir_percentage
    "re_used"
  end

  include ModelsWatcher
  watch_fields :provider_group_id, :ceil_down, :ceil_up,
               :burst_down, :burst_up, :long_download_max, :long_upload_max

  validates_uniqueness_of :name
  validates_presence_of :name, :provider_group, :ceil_down, :ceil_up
  validates_length_of :name, :in => 3..128
  validates_numericality_of :ceil_down, :ceil_up, :only_integer => true, :allow_nil => true, :greater_than_or_equal_to => 0
  validates_numericality_of :burst_down, :burst_up, :only_integer => true, :greater_than_or_equal_to => 0
  validates_numericality_of :long_download_max, :long_upload_max, :only_integer => true, :greater_than_or_equal_to => 0, :less_than => 4294967295

  validate :ceil_down_different_to_zero
  validate :ceil_up_different_to_zero

  # before_save :set_if_used_cir_percentage_or_used_total_cir
  # before_save :set_cir, :if => "used_total_cir == false and (used_cir_percentage_changed? and used_cir_percentage == false)"
  # before_save :set_total_cir, :if => "used_total_cir_changed?"

  before_save :set_cir_and_total_cir

  def set_total_cir
    self.total_cir_up = self.ceil_up * self.cir_up * self.contracts.count rescue 0
    self.total_cir_down = self.ceil_down * self.cir_down * self.contracts.count rescue 0
  end

  def set_cir_and_total_cir
    self.used_total_cir = false
    self.used_cir_percentage = false
    case how_use_cir
    when "percentage"
      self.used_cir_percentage = true
    when "total_cir"
      self.used_total_cir = true
    end
    set_cir
    set_total_cir unless used_total_cir
  end

  def set_cir
    if used_total_cir
      self.cir_up = self.total_cir_up / (self.ceil_up * self.contracts.count) rescue 0.0001
      self.cir_down = self.total_cir_down / (self.ceil_down * self.contracts.count) rescue 0.0001
    else
      if used_cir_percentage
        self.cir_up = self.cir_down = self.cir_percentage
      else
        self.cir_up = self.cir_down = self.value_cir_re_used
      end
    end
  end

  def real_total_cir_up
    pg = provider_group
    [(pg.rate_down * self.total_cir_down / pg.total_cir_down), total_cir_up].min
  end

  def real_total_cir_down
    pg = provider_group
    [(pg.rate_up * self.total_cir_up / pg.total_cir_up), total_cir_down].min
  end

  def cir_factor_up
    real_total_cir_up / contracts.count
  end

  def cir_factor_down
    real_total_cir_down / contracts.count
  end

  def rate_up
    ceil_up * cir_up rescue 0
  end

  def rate_down
    ceil_down * cir_down rescue 0
  end

  def ceil_up_different_to_zero
    errors.add(:ceil_up, I18n.t('validations.plan.ceil_up_different_to_zero')) if ceil_up == 0
  end

  def ceil_down_different_to_zero
    errors.add(:ceil_down, I18n.t('validations.plan.ceil_down_different_to_zero')) if ceil_down == 0
  end

  def burst_down_to_bytes
    (burst_down / 8) * 1024
  end
  def burst_up_to_bytes
    (burst_up / 8) * 1024
  end
  def long_download_max_to_bytes
    long_download_max * 1024
  end
  def long_upload_max_to_bytes
    long_upload_max * 1024
  end
  def auditable_name
    "#{self.class.human_name}: #{name}"
  end
end
