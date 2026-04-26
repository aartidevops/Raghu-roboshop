variable "project"             { type = string }
variable "env"                 { type = string }
variable "location"            { type = string }
variable "resource_group_name"{ type = string }
variable "agw_subnet_id"       { type = string }
variable "tags"                { type = map(string); default = {} }