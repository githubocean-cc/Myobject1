set ::__top_name [get_top]
set ::__top_name_len [string length $::__top_name]
set ::__param_top_sw [expr {[get_param db.use_hier_name_include_top] == "true"}]
proc ::__is_obj {obj} {
	if {[get_instances $obj] != ""} {
		return 1
	}
	if {[get_nets $obj] != ""} {
		return 1
	}
	if {[get_ports $obj] != ""} {
		return 1
	}
	if {[get_pins $obj] != ""} {
		return 1
	}
	return 0
}
proc DFT::s_to_e_obj {obj} {
	## 对[6, 4:3, 1:0]的情况进行递归处理
	if {[string match {*\[*,*\]} $obj]} {
		set tmp_seq_list [concat {*}[split [lindex [regexp -inline {\[([^\[]*?\d+,\s*\d+[^\]]*?)\]}]]]]
		set tmp_fmt [regsub {\[[^\[]*?\d+,\s*\d+[^\]]*?\]} $obj {[%s]}]
		set result ""
		foreach i $tmp_seq_list {
			set j [::__s_to_e_obj [format $tmp_fmt $i]]
			if {$j != $i} {
				lappend result $j
			} else {
				return $obj
			}
		}
		return $result
	}

	## 兼顾struct和generate进行分割字符串
	set tmp_obj [string map {" .\\" {`!} ".\\" {`!} " ." ` " " ""} $obj]

	## 检查并去掉原字符串头部的top
	set have_top [string match "${DFT::top_name}.*" $tmp_obj]
	if {$have_top} {
		set tmp_obj [string range $tmp_obj $DFT::top_name_len+1 end]
	}

	## 处理struct和generate等特殊的子串
	set str_list [split $tmp_obj "`"]
	foreach i [split $tmp_obj "`"] {
		if {[string first {!} $i] == 0} {
			set l_i [string range $i 1 end]
		} else {
			set l_i [split $i .]
		}
		foreach j $l_i {
			if {[string match {*\[[a-zA-Z_]*} $i]} {
				set j [regsub -all {\[([a-zA-Z_]\w*)\]} $i {.\1}]
			}
			lappend str_list $j
		}
	}

	## 对新字符头部增删top
	if {$DFT::param_top_sw} {
		set result $DFT::top_name
	} else {
		set result ""
	}
	set idx 0
	while {1} {
		set sub_str_i [lindex $str_list $idx]
		if {$sub_str_i == ""} {break}
		incr idx

		set tmp [join [concat $result $sub_str_i] /]
		if {[DFT::is_obj $tmp]} {
			set result $tmp
			continue
		}

		## 处理特殊的子串
		# step1
		set di {CLR r PRE s En s D d Q q CP clk}
		if {[dict exists $di $sub_str_i]} {
			set tmp [join [concat $result $sub_str_i] /]
			if {[DFT::is_obj $tmp]} {
				set result $tmp
				continue
			}
		}

		# step2
		if {[string match {*_reg} $sub_str_i]} {
			set sub_str_i [string range $sub_str_i 0 end-4]
			set tmp [join [concat $result $sub_str_i] /]
			if {[DFT::is_obj $tmp]} {
				set result $tmp
				continue
			}
		}

		# step3
		if {[string match {*_reg\[[0-9]*} $sub_str_i]} {
			set sub_str_i [string map {_reg[ [} $sub_str_i]
			set tmp [join [concat $result $sub_str_i] /]
			if {[DFT::is_obj $tmp]} {
				set result $tmp
				continue
			}
		}

		# step4
		if {[string match {rtlc_I*} $sub_str_i]} {
			set sub_str_i [string map {rtlc_I i} $sub_str_i]
			set tmp [join [concat $result $sub_str_i] /]
			if {[DFT::is_obj $tmp]} {
				set result $tmp
				continue
			}
		}
		return $obj
	}
	set result [concat {*}$result]
	return $result
}
