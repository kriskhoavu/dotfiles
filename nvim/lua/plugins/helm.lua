-- Helm templates are Go templates, not YAML: yamlls reports every {{ ... }} as
-- "Missing , or : between flow map items". This plugin detects charts as the
-- "helm" filetype -- which yamlls ignores and helm_ls claims -- and brings the
-- syntax that plain YAML highlighting cannot provide for the template blocks.
return {
	"towolf/vim-helm",
	lazy = false, -- its ftdetect has to run before the first chart file opens
}
