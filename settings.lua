data:extend({
  {
    type = "int-setting",
    name = "capsule-ammo-combination-levels",
    setting_type = "startup",
    default_value = 4,
    minimum_value = 0,
    order = 'a',
  },{
    type = "string-setting",
    name = "capsule-ammo-technology",
    setting_type = "startup",
    default_value = 'Complete',
    allowed_values = {'No', 'Levels only', 'Individual recipes', 'Complete'},
    order = 'b',
  },{
    type = "string-setting",
    name = "capsule-ammo-recipe-type",
    setting_type = "startup",
    default_value = 'Simple',
    allowed_values = {'Simple', 'Complex, cheap', 'Complex, expensive'},
    order = 'c',
  },{
    type = "double-setting",
    name = "capsule-ammo-magazine-fraction",
    setting_type = "startup",
    default_value = 0.30,
    minimum_value = 0,
    maximume_value = 1,
    order = 'd',
  },{
    type = "string-setting",
    name = "capsule-ammo-blacklist-ammo",
    setting_type = "startup",
    default_value = "",
    allow_blank = true,
    order = 'e',
  },{
    type = "string-setting",
    name = "capsule-ammo-blacklist-capsule",
    setting_type = "startup",
    default_value = "",
    allow_blank = true,
    order = 'f',
  },{
    type = "bool-setting",
    name = "capsule-ammo-enable-extra-laser-ammo-types",
    setting_type = "startup",
    default_value = false,
    order = 'g',
  }
})