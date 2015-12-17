# Definitional proc to organize widgets for parameters.
proc init_gui { IPINST } {
  ipgui::add_param $IPINST -name "Component_Name"
  #Adding Page
  set Page_0 [ipgui::add_page $IPINST -name "Page 0"]
  ipgui::add_param $IPINST -name "N_LANES" -parent ${Page_0}
  ipgui::add_param $IPINST -name "PHY_INV_CLK" -parent ${Page_0}
  ipgui::add_param $IPINST -name "PHY_INV_DATA" -parent ${Page_0}


}

proc update_PARAM_VALUE.N_LANES { PARAM_VALUE.N_LANES } {
	# Procedure called to update N_LANES when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.N_LANES { PARAM_VALUE.N_LANES } {
	# Procedure called to validate N_LANES
	return true
}

proc update_PARAM_VALUE.PHY_INV_CLK { PARAM_VALUE.PHY_INV_CLK } {
	# Procedure called to update PHY_INV_CLK when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.PHY_INV_CLK { PARAM_VALUE.PHY_INV_CLK } {
	# Procedure called to validate PHY_INV_CLK
	return true
}

proc update_PARAM_VALUE.PHY_INV_DATA { PARAM_VALUE.PHY_INV_DATA } {
	# Procedure called to update PHY_INV_DATA when any of the dependent parameters in the arguments change
}

proc validate_PARAM_VALUE.PHY_INV_DATA { PARAM_VALUE.PHY_INV_DATA } {
	# Procedure called to validate PHY_INV_DATA
	return true
}


proc update_MODELPARAM_VALUE.N_LANES { MODELPARAM_VALUE.N_LANES PARAM_VALUE.N_LANES } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.N_LANES}] ${MODELPARAM_VALUE.N_LANES}
}

proc update_MODELPARAM_VALUE.PHY_INV_CLK { MODELPARAM_VALUE.PHY_INV_CLK PARAM_VALUE.PHY_INV_CLK } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.PHY_INV_CLK}] ${MODELPARAM_VALUE.PHY_INV_CLK}
}

proc update_MODELPARAM_VALUE.PHY_INV_DATA { MODELPARAM_VALUE.PHY_INV_DATA PARAM_VALUE.PHY_INV_DATA } {
	# Procedure called to set VHDL generic/Verilog parameter value(s) based on TCL parameter value
	set_property value [get_property value ${PARAM_VALUE.PHY_INV_DATA}] ${MODELPARAM_VALUE.PHY_INV_DATA}
}

