/datum/job/chief_medical_officer
	title = JOB_NAME_CHIEFMEDICALOFFICER
	flag = CMO_JF
	department_head = list(JOB_NAME_CAPTAIN)
	department_flag = MEDSCI
	auto_deadmin_role_flags = DEADMIN_POSITION_HEAD
	head_announce = list(RADIO_CHANNEL_MEDICAL)
	faction = "Station"
	total_positions = 1
	spawn_positions = 1
	supervisors = "the captain"
	selection_color = "#c1e1ec"
	req_admin_notify = 1
	minimal_player_age = 7
	exp_requirements = 1200
	exp_type = EXP_TYPE_MEDICAL
	exp_type_department = EXP_TYPE_MEDICAL

	outfit = /datum/outfit/job/chief_medical_officer

	access = list(ACCESS_MEDICAL, ACCESS_MORGUE, ACCESS_GENETICS, ACCESS_CLONING, ACCESS_HEADS, ACCESS_MINERAL_STOREROOM,
			ACCESS_CHEMISTRY, ACCESS_VIROLOGY, ACCESS_CMO, ACCESS_SURGERY, ACCESS_RC_ANNOUNCE, ACCESS_MECH_MEDICAL,
			ACCESS_KEYCARD_AUTH, ACCESS_SEC_DOORS, ACCESS_MAINT_TUNNELS, ACCESS_BRIGPHYS, ACCESS_EVA, ACCESS_EXTERNAL_AIRLOCKS, ACCESS_WEAPONS)
	minimal_access = list(ACCESS_MEDICAL, ACCESS_MORGUE, ACCESS_GENETICS, ACCESS_CLONING, ACCESS_HEADS, ACCESS_MINERAL_STOREROOM,
			ACCESS_CHEMISTRY, ACCESS_VIROLOGY, ACCESS_CMO, ACCESS_SURGERY, ACCESS_RC_ANNOUNCE, ACCESS_MECH_MEDICAL,
			ACCESS_KEYCARD_AUTH, ACCESS_SEC_DOORS, ACCESS_MAINT_TUNNELS, ACCESS_BRIGPHYS, ACCESS_EVA, ACCESS_EXTERNAL_AIRLOCKS, ACCESS_WEAPONS)
	paycheck = PAYCHECK_COMMAND
	paycheck_department = ACCOUNT_MED
	mind_traits = list(TRAIT_MEDICAL_METABOLISM)

	display_order = JOB_DISPLAY_ORDER_CHIEF_MEDICAL_OFFICER
	departments = DEPARTMENT_BITFLAG_MEDICAL | DEPARTMENT_BITFLAG_COMMAND
	rpg_title = "High Cleric"

	species_outfits = list(
		SPECIES_PLASMAMAN = /datum/outfit/plasmaman/cmo
	)
	biohazard = 20

/datum/outfit/job/chief_medical_officer
	name = JOB_NAME_CHIEFMEDICALOFFICER
	jobtype = /datum/job/chief_medical_officer

	id = /obj/item/card/id/job/chief_medical_officer
	belt = /obj/item/pda/heads/chief_medical_officer
	l_pocket = /obj/item/pinpointer/crew
	ears = /obj/item/radio/headset/heads/cmo
	uniform = /obj/item/clothing/under/rank/medical/chief_medical_officer
	shoes = /obj/item/clothing/shoes/sneakers/brown
	suit = /obj/item/clothing/suit/toggle/labcoat/cmo
	l_hand = /obj/item/storage/firstaid/medical
	suit_store = /obj/item/flashlight/pen
	backpack_contents = list(/obj/item/melee/classic_baton/police/telescopic=1,
		/obj/item/modular_computer/tablet/preset/advanced/command=1)

	backpack = /obj/item/storage/backpack/medic
	satchel = /obj/item/storage/backpack/satchel/med
	duffelbag = /obj/item/storage/backpack/duffelbag/med

	chameleon_extras = list(/obj/item/gun/syringe, /obj/item/stamp/cmo)

/datum/outfit/job/chief_medical_officer/hardsuit
	name = "Chief Medical Officer (Hardsuit)"

	mask = /obj/item/clothing/mask/breath
	suit = /obj/item/clothing/suit/space/hardsuit/medical/cmo
	suit_store = /obj/item/tank/internals/oxygen
	r_pocket = /obj/item/flashlight/pen
