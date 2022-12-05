GLOBAL_LIST_INIT(uplink_items, subtypesof(/datum/uplink_item))
/proc/get_uplink_items(uplink_flag, allow_sales = TRUE, allow_restricted = TRUE)
	var/list/filtered_uplink_items = list()
	var/list/sale_items = list()

	for(var/path in GLOB.uplink_items)
		var/datum/uplink_item/I = new path
		if(!I.item)
			continue
		if (!(I.purchasable_from & uplink_flag))
			continue
		if(I.player_minimum && I.player_minimum > GLOB.joined_player_list.len)
			continue
		if (I.restricted && !allow_restricted)
			continue
		if(!filtered_uplink_items[I.category])
			filtered_uplink_items[I.category] = list()
		filtered_uplink_items[I.category][I.name] = I
		if(I.limited_stock < 0 && !I.cant_discount && I.item)
			sale_items += I

	if(allow_sales)
		var/datum/team/nuclear/nuclear_team
		if (uplink_flag & UPLINK_NUKE_OPS) 					// uplink code kind of needs a redesign
			nuclear_team = locate() in GLOB.antagonist_teams	// the team discounts could be a in a GLOB with this design but it would make sense for them to be team specific...
		if (!nuclear_team)
			create_uplink_sales(3, "割引対象商品", 1, sale_items, filtered_uplink_items)
		else
			if (!nuclear_team.team_discounts)
				// create 5 unlimited stock discounts
				create_uplink_sales(5, "チーム割引商品", -1, sale_items, filtered_uplink_items)
				// Create 10 limited stock discounts
				create_uplink_sales(10, "数量限定のチームアイテム", 1, sale_items, filtered_uplink_items)
				nuclear_team.team_discounts = list("チーム割引商品" = filtered_uplink_items["チーム割引商品"], "数量限定のチームアイテム" = filtered_uplink_items["数量限定のチームアイテム"])
			else
				for(var/cat in nuclear_team.team_discounts)
					for(var/item in nuclear_team.team_discounts[cat])
						var/datum/uplink_item/D = nuclear_team.team_discounts[cat][item]
						var/datum/uplink_item/O = filtered_uplink_items[initial(D.category)][initial(D.name)]
						O.refundable = FALSE

				filtered_uplink_items["チーム割引商品"] = nuclear_team.team_discounts["チーム割引商品"]
				filtered_uplink_items["数量限定のチームアイテム"] = nuclear_team.team_discounts["数量限定のチームアイテム"]


	return filtered_uplink_items

/proc/create_uplink_sales(num, category_name, limited_stock, sale_items, uplink_items)
	if (num <= 0)
		return

	if(!uplink_items[category_name])
		uplink_items[category_name] = list()

	for (var/i in 1 to num)
		var/datum/uplink_item/I = pick_n_take(sale_items)
		var/datum/uplink_item/A = new I.type
		var/list/disclaimer = list("お子様にはお勧めできません。", "小さな部品が含まれています。", "地域の合法性については、現地の法律を確認してください。", "嘲笑してはいけない。", "本製品の欠陥、エラー、不具合に起因する直接的、間接的、偶発的、結果的な損害については責任を負いかねます。", "火や炎に近づけないでください。", "本製品は、いかなる黙示または明示の保証もなく、\"as is\"で提供されます。", "テレビで見たとおり。", "レクリエーション用としてのみ使用できます。", "指示された方法でのみ使用してください。", "スペースネブラスカ州内で発生した注文には、16％の消費税が課されます。")
		A.limited_stock = limited_stock
		A.category = category_name
		I.refundable = FALSE //THIS MAN USES ONE WEIRD TRICK TO GAIN FREE TC, CODERS HATES HIM!
		A.refundable = FALSE
		switch(A.cost == 1 ? 1 : rand(1, 5))
			if(1 to 3)
				if(A.cost <= 3)
					//Bulk discount
					var/count = rand(3,7)
					var/discount = A.get_discount()
					A.name += " (まとめ買い割引: - 購入する [count] を [((1-discount)*100)]%で購入する!)"
					A.cost = max(round(A.cost*count*discount), 1)
					A.desc += " 通常コスト: [initial(A.cost)*count] TC. [pick(disclaimer)]"
					A.spawn_amount = count
				else
					//X% off!
					var/discount = A.get_discount()
					if(A.cost >= 20) //Tough love for nuke ops
						discount *= 0.5
					A.cost = max(round(A.cost * discount), 1)
					A.name += " ([round(((initial(A.cost)-A.cost)/initial(A.cost))*100)]% off!)"
					A.desc += " 通常コスト: [initial(A.cost)] TC. [pick(disclaimer)]"
			if(4)
				//Buy 1 get 1 free!
				A.name += " (1個買うと1個無料!)"
				A.desc += " 1の価格で2が手に入る。[pick(disclaimer)]"
				A.spawn_amount = 2
			if(5)
				//Get 2 items with their combined price reduced.
				var/datum/uplink_item/second_I = pick_n_take(sale_items)
				var/total_cost = second_I.cost + I.cost
				var/discount = A.get_discount()
				var/final_cost = max(round(total_cost * discount), 1)
				//Setup the item
				A.cost = final_cost
				A.name += " + [second_I.name] (バンドル割引 - [100-(round((final_cost / total_cost)*100))]%で購入する!)"
				A.desc += " も収録されています - [second_I.name]. 通常、一緒に購入すると [total_cost] TCになる. [pick(disclaimer)]"
				A.bonus_items = list(second_I.item)
		A.discounted = TRUE
		A.item = I.item
		uplink_items[category_name][A.name] = A



/**
 * Uplink Items
 *
 * Items that can be spawned from an uplink. Can be limited by gamemode.
**/
/datum/uplink_item
	var/name = "item name"
	var/category = "item category"
	var/desc = "item description"
	var/item = null // Path to the item to spawn.
	var/refund_path = null // Alternative path for refunds, in case the item purchased isn't what is actually refunded (ie: holoparasites).
	var/cost = 0
	var/refund_amount = 0 // specified refund amount in case there needs to be a TC penalty for refunds.
	var/refundable = FALSE
	var/surplus = 100 // Chance of being included in the surplus crate.
	var/cant_discount = FALSE
	var/murderbone_type = FALSE
	var/limited_stock = -1 //Setting this above zero limits how many times this item can be bought by the same traitor in a round, -1 is unlimited
	var/purchasable_from = ALL
	var/list/restricted_roles = list() //If this uplink item is only available to certain roles. Roles are dependent on the frequency chip or stored ID.
	var/player_minimum //The minimum crew size needed for this item to be added to uplinks.
	var/purchase_log_vis = TRUE // Visible in the purchase log?
	var/restricted = FALSE // Adds restrictions for VR/Events
	var/list/restricted_species //Limits items to a specific species. Hopefully.
	var/illegal_tech = TRUE // Can this item be deconstructed to unlock certain techweb research nodes?
	var/discounted = FALSE
	var/spawn_amount = 1	//How many times we should run the spawn
	var/bonus_items	= null	//Bonus items you gain if you purchase it

/datum/uplink_item/proc/get_discount()
	return pick(4;0.75,2;0.5,1;0.25)

/datum/uplink_item/proc/purchase(mob/user, datum/component/uplink/U)
	//Spawn base items
	for(var/i in 1 to spawn_amount)
		var/atom/A = spawn_item(item, user, U)
		if(purchase_log_vis && U.purchase_log)
			U.purchase_log.LogPurchase(A, src, cost)
	//Spawn bonust items
	if(islist(bonus_items))
		for(var/bonus in bonus_items)
			var/atom/A = spawn_item(bonus, user, U)
			if(purchase_log_vis && U.purchase_log)
				U.purchase_log.LogPurchase(A, src, cost)

/datum/uplink_item/proc/spawn_item(spawn_path, mob/user, datum/component/uplink/U)
	if(!spawn_path)
		return
	var/atom/A
	if(ispath(spawn_path))
		A = new spawn_path(get_turf(user))
	else
		A = spawn_path
	if(istype(A, /obj/item))
		var/obj/item/I = A
		I.item_flags |= ILLEGAL
		if(ishuman(user))
			var/mob/living/carbon/human/H = user
			if(H.put_in_hands(A))
				to_chat(H, "[A] があなたの手に実体化!")
				return A
	to_chat(user, "[A] が床に現れる。")
	return A

//Discounts (dynamically filled above)
/datum/uplink_item/discounts
	category = "割引情報"

//All bundles and telecrystals
/datum/uplink_item/bundles_TC
	category = "バンドル"
	surplus = 0
	cant_discount = TRUE

/datum/uplink_item/bundles_TC/chemical
	name = "バイオテロバンドル"
	desc = "狂人用 バイオテロ化学噴霧器、バイオテロ発泡手榴弾、致死性化学物質の箱、ダーツピストル、注射器、ドンクソフトアサルトライフル、 \
			暴動用ダーツが含まれている。注射器の箱、ドンクソフト・アサルトライフル、ライオットダーツがある。忘れないで 使用前にスーツと装備の内部を 密閉すること"
	item = /obj/item/storage/backpack/duffelbag/syndie/med/bioterrorbundle
	cost = 30 // normally 42
	purchasable_from = UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS

/datum/uplink_item/bundles_TC/bulldog
	name = "ブルドッグバンドル"
	desc = "無駄をそぎ落とし 間近で見たい人に最適です。人気のブルドッグショットガン、 \
			12gバックショットドラム2本、サーマルイメージングゴーグル1個を同梱。"
	item = /obj/item/storage/backpack/duffelbag/syndie/bulldogbundle
	cost = 13 // normally 16
	purchasable_from = UPLINK_NUKE_OPS

/datum/uplink_item/bundles_TC/c20r
	name = "C-20rバンドル"
	desc = "信頼のおける友人。定番のC-20rにマガジン2本とサプレッサー（余剰品）をバンドルし、格安で販売します。"
	item = /obj/item/storage/backpack/duffelbag/syndie/c20rbundle
	cost = 14 // normally 16
	purchasable_from = UPLINK_NUKE_OPS

/datum/uplink_item/bundles_TC/cyber_implants
	name = "サイバネティック・インプラント・バンドル"
	desc = "サイバネティックインプラントがランダムで入っています。高品質なインプラント5個を保証。オートサージェリー付き。"
	item = /obj/item/storage/box/cyber_implants
	cost = 40
	purchasable_from = UPLINK_NUKE_OPS

/datum/uplink_item/bundles_TC/medical
	name = "医療用バンドル"
	desc = "サポートのスペシャリスト。このメディカルバンドルで仲間を助けよう。タクティカル・メディカルキット、 \
			ドンクソフトLMG、ライオットダーツ、マグブーツが含まれ、無重力の環境下で仲間を救出することができます。"
	item = /obj/item/storage/backpack/duffelbag/syndie/med/medicalbundle
	cost = 15 // normally 20
	purchasable_from = UPLINK_NUKE_OPS

/datum/uplink_item/bundles_TC/sniper
	name = "スナイパーバンドル"
	desc = "エレガントで洗練されたデザイン。高価なキャリングケースに入った伸縮式スナイパーライフル、 \
			強力なノックアウトマガジン2本、サプレッサー（無料）、そしてシャープなタートルネックスーツがセットになっています。"
	item = /obj/item/storage/briefcase/sniperbundle
	cost = 20 // normally 26
	purchasable_from = UPLINK_NUKE_OPS

/datum/uplink_item/bundles_TC/firestarter
	name = "スペツナズパイロバンドル"
	desc = "近接戦での炭素系生命体の 制圧を目的とする ニューロシアン・バックパックスプレー、エリート・ハードスーツ、ステフキン・ＡＰＳピストル、 \
			マガジン2本、ミニ爆弾、覚醒剤注射器が含まれています。"
	item = /obj/item/storage/backpack/duffelbag/syndie/firestarter
	cost = 30
	purchasable_from = UPLINK_NUKE_OPS

/datum/uplink_item/bundles_TC/contract_kit
	name = "コントラクトキット"
	desc = "シンジケートから請負人として誘拐を請け負い、TCと現金を手に入れるチャンスがある。購入すると、 \
			付属のタブレットPCにあなた専用の契約アップリンクが組み込まれます。タブレット、特殊な宇宙服、カメレオンジャンプスーツとマスク、 \
			エージェントカード、特殊な契約者バトン、そしてランダムで3つの低コストアイテムが付属します。入手不可能なアイテムが含まれることもあります。"
	item = /obj/item/storage/box/syndie_kit/contract_kit
	cost = 20
	player_minimum = 15
	purchasable_from = ~(UPLINK_INCURSION | UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS)

/datum/uplink_item/bundles_TC/bundle_A
	name = "シンジキット・タクティカル"
	desc = "シンジケートバンドルは、シンジキットと呼ばれ、無地の箱に入った専門的な商品群のことです。 \
			これらのアイテムは合計で20テレクリスタル以上の価値がありますが、 \
			どの特化したものを受け取れるかはわかりません。生産中止のアイテムやエキゾチックなアイテムが入っている場合があります。"
	item = /obj/item/storage/box/syndie_kit/bundle_A
	cost = 20
	purchasable_from = ~(UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS)

/datum/uplink_item/bundles_TC/bundle_B
	name = "シンディキット・スペシャル"
	desc = "シンジケートバンドルは、シンジキットと呼ばれ、無地の箱に入った専門的な商品群のことです。 \
			シンジキットスペシャルでは、過去の有名なシンジケートエージェントが使用したアイテムがもらえます。20個以上のテレクリスタルの価値があり、シンジケートは古き良き時代を懐かしんでいる。"
	item = /obj/item/storage/box/syndie_kit/bundle_B
	cost = 20
	purchasable_from = ~(UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS)

/datum/uplink_item/bundles_TC/surplus
	name = "シンジケートサープラスクレート"
	desc = "シンジケートの倉庫の奥にあった埃まみれの木箱。貴重なアイテムが入っているという噂だが、果たしてどうだろう。中身は常に50TCの価値があるように仕分けされている。"
	item = /obj/structure/closet/crate
	cost = 20
	player_minimum = 20
	purchasable_from = ~(UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS)
	var/starting_crate_value = 50
	var/uplink_contents = UPLINK_TRAITORS

/datum/uplink_item/bundles_TC/surplus/super
	name = "スーパーサープラス・クレート"
	desc = "シンジケートの倉庫の奥にあった埃まみれの超大型。貴重なアイテムが入っているとの噂だが、果たしてどうだろう。 \
			中身は常に125TCの価値があるように仕分けされている。"
	cost = 40
	player_minimum = 30
	starting_crate_value = 125
	purchasable_from = ~(UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS)

/datum/uplink_item/bundles_TC/surplus/purchase(mob/user, datum/component/uplink/U)
	var/list/uplink_items = get_uplink_items(uplink_contents, FALSE)

	var/crate_value = starting_crate_value
	var/obj/structure/closet/crate/C = spawn_item(/obj/structure/closet/crate, user, U)
	if(U.purchase_log)
		U.purchase_log.LogPurchase(C, src, cost)
	while(crate_value)
		var/category = pick(uplink_items)
		var/item = pick(uplink_items[category])
		var/datum/uplink_item/I = uplink_items[category][item]

		if(!I.surplus || prob(100 - I.surplus))
			continue
		if(crate_value < I.cost)
			continue
		crate_value -= I.cost
		var/obj/goods = new I.item(C)
		if(U.purchase_log)
			U.purchase_log.LogPurchase(goods, I, 0)
	return C

//Will either give you complete crap or overpowered as fuck gear
/datum/uplink_item/bundles_TC/surplus/random
	name = "シンジケートのLootbox"
	desc = "シンジケートの倉庫の奥にあった埃まみれの木箱。貴重な品々が入っていると噂されている, \
			新商品はすべて「詐欺」のレッテルを貼られた。lootbox的なシステムを作ろうとして失敗した。 \
			アイテム価格が保証されていない。通常では入手不可能なアイテムが含まれている可能性がある。"
	purchasable_from = ~(UPLINK_INCURSION | UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS)
	uplink_contents = (UPLINK_TRAITORS | UPLINK_NUKE_OPS)
	player_minimum = 30

/datum/uplink_item/bundles_TC/surplus/random/purchase(mob/user, datum/component/uplink/U)
	var/index = rand(1, 20)
	starting_crate_value = index * 5
	if(index == 1)
		to_chat(user, "<span class='warning'><b>シンジケートからの着信。</b></span>")
		to_chat(user, "<span class='warning'>圧倒的なプライドと達成感を感じる。</span>")
		var/obj/item/clothing/mask/joy/funny_mask = new(get_turf(user))
		ADD_TRAIT(funny_mask, TRAIT_NODROP, CURSED_ITEM_TRAIT)
		var/obj/item/I = user.get_item_by_slot(ITEM_SLOT_MASK)
		if(I)
			user.dropItemToGround(I, TRUE)
		user.equip_to_slot_if_possible(funny_mask, ITEM_SLOT_MASK)
	else if(index == 20)
		starting_crate_value = 200
		print_command_report("[user]さん、シンジケートのくじ引きで [rand(4, 9)] 番目に当選されたとのこと、おめでとうございます。 \
		セイバートゥース提督はあなたの特別な装備の転送を許可しました。ハッピーハンティング オペレーター", "シンジケート賭博部門最高司令部",
		"シンジケート・ギャンブル部門最高司令部", TRUE)
	var/obj/item/implant/weapons_auth/W = new
	W.implant(user)	//Gives them the ability to use restricted weapons
	. = ..()

/datum/uplink_item/bundles_TC/random
	name = "ランダムアイテム"
	desc = "これを選ぶと、ランダムでアイテムが購入できます。TCに余裕があるときや、まだ作戦を決めていないときに便利です。"
	item = /obj/effect/gibspawner/generic // non-tangible item because techwebs use this path to determine illegal tech
	cost = 0

/datum/uplink_item/bundles_TC/random/purchase(mob/user, datum/component/uplink/U)
	var/list/uplink_items = U.uplink_items
	var/list/possible_items = list()
	for(var/category in uplink_items)
		for(var/item in uplink_items[category])
			var/datum/uplink_item/I = uplink_items[category][item]
			if(src == I || !I.item)
				continue
			if(U.telecrystals < I.cost)
				continue
			if(I.limited_stock == 0)
				continue
			possible_items += I

	if(possible_items.len)
		var/datum/uplink_item/I = pick(possible_items)
		SSblackbox.record_feedback("tally", "traitor_random_uplink_items_gotten", 1, initial(I.name))
		U.MakePurchase(user, I)

/datum/uplink_item/bundles_TC/telecrystal
	name = "生のテレクリスタル 1個"
	desc = "純度の高いテレクリスタル1個。アクティブなアップリンクに使用すると、テレクリスタルの数が増加する。"
	item = /obj/item/stack/telecrystal
	cost = 1
	// Don't add telecrystals to the purchase_log since
	// it's just used to buy more items (including itself!)
	purchase_log_vis = FALSE

/datum/uplink_item/bundles_TC/telecrystal/five
	name = "生のテレクリスタル 5個"
	desc = "純度の高いテレクリスタル5個。アクティブなアップリンクに使用すると、テレクリスタルの数が増加する。"
	item = /obj/item/stack/telecrystal/five
	cost = 5

/datum/uplink_item/bundles_TC/telecrystal/twenty
	name = "生のテレクリスタル 20個"
	desc = "純度の高いテレクリスタル20個。アクティブなアップリンクに使用すると、テレクリスタルの数が増加する。"
	item = /obj/item/stack/telecrystal/twenty
	cost = 20

/datum/uplink_item/bundles_TC/crate
	name = "バルクハードスーツバンドル"
	desc = "シンジケートの貴重なハードスーツが4つ入った木箱。"
	cost = 18
	purchasable_from = UPLINK_INCURSION
	item = /obj/effect/gibspawner/generic
	var/list/contents = list(
		/obj/item/clothing/suit/space/hardsuit/syndi = 4,
		/obj/item/clothing/mask/gas/syndicate = 4,
		/obj/item/tank/internals/oxygen = 4
	)

/datum/uplink_item/bundles_TC/crate/purchase(mob/user, datum/component/uplink/U)
	var/obj/structure/closet/crate/C = spawn_item(/obj/structure/closet/crate, user, U)
	if(U.purchase_log)
		U.purchase_log.LogPurchase(C, src, cost)
	for(var/I in contents)
		var/count = contents[I]
		for(var/index in 1 to count)
			new I(C)
	return C

/datum/uplink_item/bundles_TC/crate/medical
	name = "シンジケート・メディカル・バンドル"
	desc = "あなたとあなたのチームのためのシンジケートの医療機器のアソートが含まれています。\
			各種救急キット、ピルボトル、小型除細動器、スティムパック4個が付属しています。"
	cost = 12
	contents = list(
		/obj/item/storage/firstaid/tactical = 2,	//8 TC
		/obj/item/storage/firstaid/brute = 2,
		/obj/item/storage/firstaid/fire = 2,
		/obj/item/storage/firstaid/toxin = 1,
		/obj/item/storage/firstaid/o2 = 1,
		/obj/item/storage/pill_bottle/mutadone = 1,
		/obj/item/storage/pill_bottle/neurine = 1,
		/obj/item/reagent_containers/hypospray/medipen/stimpack/traitor = 4
	)

/datum/uplink_item/bundles_TC/crate/shuttle
	name = "盗難シャトル作成キット"
	desc = "シンジケートのチームにはシャトルが必要だ 支給されなかったのは残念だが、TCに余裕があれば問題ないだろう。\
			新しいシャトル作成キット（シンジケートが作成）には、飛行に必要なものがすべて含まれています。\
			シンジケートのエージェントは製品のナノトラセンラベルを無視することをお勧めします。宇宙服は含まれません。"
	cost = 15	//There are multiple uses for the RCD and plasma canister, but both are easilly accessible for items that cost less than all of their TC.
	contents = list(
		/obj/machinery/portable_atmospherics/canister/toxins = 1,
		/obj/item/construction/rcd/combat = 1,
		/obj/item/rcd_ammo/large = 2,
		/obj/item/shuttle_creator = 1,
		/obj/item/pipe_dispenser = 2,
		/obj/item/storage/toolbox/syndicate = 2,
		/obj/item/storage/toolbox/electrical = 1,
		/obj/item/circuitboard/computer/shuttle/flight_control = 1,
		/obj/item/circuitboard/machine/shuttle/engine/plasma = 2,
		/obj/item/circuitboard/machine/shuttle/heater = 2,
		/obj/item/storage/part_replacer/cargo = 1,
		/obj/item/electronics/apc = 1,
		/obj/item/wallframe/apc = 1
	)

// Dangerous Items
/datum/uplink_item/dangerous
	category = "目立つ武器"

/datum/uplink_item/dangerous/poisonknife
	name = "毒入りナイフ"
	desc = "カミソリのような鋭い2枚の刃でできたナイフで、柄の部分には何かを刺すときに注入する液体を入れるための秘密の収納スペースがあります。"
	item = /obj/item/kitchen/knife/poison
	cost = 8 // all in all it's not super stealthy and you have to get some chemicals yourself

/datum/uplink_item/dangerous/rawketlawnchair
	name = "84mm ロケット弾発射機"
	desc = "再使用可能なロケット弾ランチャーで、低収量の84mmHE弾を予め装填している。 \
		発射された弾丸は、発射された瞬間に爆発するか、発射された弾丸代が返金されます!"
	item = /obj/item/gun/ballistic/rocketlauncher
	cost = 8
	surplus = 30
	purchasable_from = UPLINK_NUKE_OPS

/datum/uplink_item/dangerous/grenadelauncher
	name = "汎用グレネードランチャー"
	desc = "再使用可能なグレネードランチャー。弾薬は3発まで装填可能だが、プリロードはされていない。手榴弾の他、数種類の爆薬が使用できる。"
	item = /obj/item/gun/grenadelauncher
	cost = 6
	surplus = 30
	purchasable_from = UPLINK_NUKE_OPS

/datum/uplink_item/dangerous/pie_cannon
	name = "バナナパイカノン"
	desc = "最大20個のパイを収納でき、2秒に1個のパイを自動で作る、特別なピエロのための特別なパイキャノンです。"
	cost = 10
	item = /obj/item/pneumatic_cannon/pie/selfcharge
	surplus = 0
	purchasable_from = UPLINK_CLOWN_OPS

/datum/uplink_item/dangerous/bananashield
	name = "バナニウムエナジーシールド"
	desc = "ピエロの最も強力な防御武器で、範囲エネルギー攻撃を発射した者に跳ね返し、ほぼ免疫を得ることができる個人用シールド。 \
		また、投げても跳ね返って人をすり抜け、外しても自分の元に戻ってくる。\
		警告：展開した状態で盾の上に立たないでください。たとえ滑り止めの靴を履いていてもです。"
	item = /obj/item/shield/energy/bananium
	cost = 16
	surplus = 0
	purchasable_from = UPLINK_CLOWN_OPS

/datum/uplink_item/dangerous/clownsword
	name = "バナニウム・エナジー・ソード"
	desc = "ダメージは与えられないが、近接攻撃、投擲衝撃、踏みつけなど、接触した者を滑らせるエネルギーソード。\
	滑り止めのついた靴でも防げないので、フレンドリーファイアに注意。"
	item = /obj/item/melee/transforming/energy/sword/bananium
	cost = 3
	surplus = 0
	purchasable_from = UPLINK_CLOWN_OPS

/datum/uplink_item/dangerous/bioterror
	name = "バイオハザード薬液噴霧器"
	desc = "選択した薬液を広範囲に散布できるハンディタイプの薬液噴霧器です。 \
			タイガー協同組合が特別に調合したもので、敵を混乱させ、ダメージを与え、行動不能にする効果がある。 \
			使用には細心の注意を払い、自身や仲間の被ばくを防いでください。"
	item = /obj/item/reagent_containers/spray/chemsprayer/bioterror
	cost = 20
	surplus = 0
	purchasable_from = (UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS)

/datum/uplink_item/dangerous/throwingweapons
	name = "投擲武器の箱"
	desc = "地球古来の武術に登場する手裏剣と強化ボーラのボックス。非常に効果的な投擲武器である。 \
			ボーラは対象を倒し、手裏剣は手足に埋め込むことができる。"
	item = /obj/item/storage/box/syndie_kit/throwing_weapons
	cost = 3
	illegal_tech = FALSE

/datum/uplink_item/dangerous/shotgun
	name = "ブルドッグ散弾銃"
	desc = "フルロードのセミオートドラム給弾式ショットガン。12gの弾丸を使用する。近接対人戦闘用に設計されている。"
	item = /obj/item/gun/ballistic/shotgun/bulldog
	cost = 8
	surplus = 40
	purchasable_from = UPLINK_NUKE_OPS

/datum/uplink_item/dangerous/smg
	name = "C-20rサブマシンガン"
	desc = "スカボロー・アームズのブルパップ式サブマシンガンのフルロードモデル。C-20rは24連マガジンで.45弾を発射し、サプレッサーに対応する。"
	item = /obj/item/gun/ballistic/automatic/c20r
	cost = 10
	surplus = 40
	purchasable_from = UPLINK_NUKE_OPS

/datum/uplink_item/dangerous/superechainsaw
	name = "スーパーエナジーチェーンソー"
	desc = "金属の代わりにプラズマを利用したエネルギーブレードを使用し、黒と赤の光沢のある仕上げが施された、非常に殺傷力の高い改造チェーンソーです。 \
	非常に効率的に物質を切り裂くが、重く、大きく、音も大きい。刃が強化され、より大きなダメージと短時間のノックダウンが可能。"
	item = /obj/item/chainsaw/energy/doom
	cost = 22
	purchasable_from = UPLINK_NUKE_OPS

/datum/uplink_item/dangerous/doublesword
	name = "両刃のエネルギー剣"
	desc = "両刃のエネルギー剣は通常のエナジーソードよりわずかにダメージが大きく、\
	すべてのエネルギー弾をそらすことができるが、振るうには両手が必要である。"
	item = /obj/item/dualsaber
	player_minimum = 25
	cost = 18
	purchasable_from = ~UPLINK_CLOWN_OPS

/datum/uplink_item/dangerous/doublesword/get_discount()
	return pick(4;0.8,2;0.65,1;0.5)

/datum/uplink_item/dangerous/sword
	name = "エネルギー剣"
	desc = "エネルギー剣は、純粋なエネルギーの刃を持つ刃物です。非活性時にはポケットに入るほど小さい。起動すると大きな独特の音がする。"
	item = /obj/item/melee/transforming/energy/sword/saber
	cost = 8
	purchasable_from = ~UPLINK_CLOWN_OPS

/datum/uplink_item/dangerous/shield
	name = "エネルギー楯"
	desc = "エネルギー弾を反射し、他の攻撃から身を守ることができる非常に便利な個人用シールドプロジェクター。エネルギー剣との組み合わせは最強。"
	item = /obj/item/shield/energy
	cost = 16
	surplus = 20
	purchasable_from = UPLINK_NUKE_OPS

/datum/uplink_item/dangerous/flamethrower
	name = "火炎放射器"
	desc = "以前、ナノトラセンステーションから盗んだ高燃焼性バイオトキシンの一部を燃料とする火炎放射器。\
	欲にまみれた汚物どもを炙り出すことで、その存在を主張する。使用には注意が必要だ。"
	item = /obj/item/flamethrower/full/tank
	cost = 4
	surplus = 40
	purchasable_from = UPLINK_NUKE_OPS
	illegal_tech = FALSE

/datum/uplink_item/dangerous/rapid
	name = "北斗の籠手"
	desc = "パンチを高速に繰り出すことができるグローブです。武器の攻撃速度やハルクのような肉厚な拳は向上しない。"
	item = /obj/item/clothing/gloves/rapid
	cost = 8

/datum/uplink_item/dangerous/guardian
	name = "ホロパラサイト"
	desc = "ハードライト・ホログラムやナノマシンを使って魔術に近い能力を発揮するが、\
	本拠地と燃料源として有機的な宿主を必要とする。ホロパラミットには様々なタイプがあり、宿主とダメージを共有する。"
	item = /obj/item/guardiancreator/tech
	cost = 18
	surplus = 10
	purchasable_from = ~(UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS)
	player_minimum = 25
	restricted = TRUE

/datum/uplink_item/dangerous/machinegun
	name = "L6分隊自動小銃"
	desc = "Aussec Armoury製ベルト給弾式機関銃のフル装備。この凶器は7.12x82mm弾を50発装填できる大容量だ"
	item = /obj/item/gun/ballistic/automatic/l6_saw
	cost = 18
	surplus = 0
	purchasable_from = UPLINK_NUKE_OPS

/datum/uplink_item/dangerous/carbine
	name = "M-90gl カービン"
	desc = "30連マガジンから5.56mm弾を発射し、トグル式の40mmアンダーバレルグレネードランチャーを備えた、フルロードの3連バースト専用カービン。"
	item = /obj/item/gun/ballistic/automatic/m90
	cost = 14
	surplus = 50
	purchasable_from = UPLINK_NUKE_OPS

/datum/uplink_item/dangerous/powerfist
	name = "パワーフィスト"
	desc = "パワーフィストは、外部ガス供給により作動するピストンラムを内蔵した金属製のガントレットである。\
	ピストンラムが前方に伸び、ターゲットに当たると大きなダメージを与える。\
	ピストンバルブのレンチを操作することで、1回のパンチで使用するガスの量を調整し、より大きなダメージと命中率を得ることができます。\
	付属のタンクはドライバーで取り外してください。"
	item = /obj/item/melee/powerfist
	cost = 6

/datum/uplink_item/dangerous/sniper
	name = "狙撃銃"
	desc = "シンジケート流のレンジ・フューリー。衝撃と畏怖を与えるか、TCを返却することを保証します。"
	item = /obj/item/gun/ballistic/automatic/sniper_rifle/syndicate
	cost = 16
	surplus = 25
	purchasable_from = UPLINK_NUKE_OPS

/datum/uplink_item/dangerous/pistol
	name = "ステフキン拳銃"
	desc = "8連マガジンで10mmオート弾を使用し、サプレッサーに対応した、小型で隠しやすいハンドガンです。"
	item = /obj/item/gun/ballistic/automatic/pistol
	cost = 7
	purchasable_from = ~UPLINK_CLOWN_OPS

/datum/uplink_item/dangerous/bolt_action
	name = "余剰ライフル"
	desc = "恐ろしく時代遅れのボルトアクション武器。これを使うには必死でなければならない。"
	item = /obj/item/gun/ballistic/rifle/boltaction
	cost = 2
	purchasable_from = UPLINK_NUKE_OPS
	illegal_tech = FALSE

/datum/uplink_item/dangerous/revolver
	name = "シンジケートの回転式拳銃"
	desc = ".357マグナム弾を発射し、7発装填できる残酷なほどシンプルなシンジケートの回転式拳銃。"
	item = /obj/item/gun/ballistic/revolver
	cost = 12
	surplus = 50
	purchasable_from = ~UPLINK_CLOWN_OPS

/datum/uplink_item/dangerous/foamsmg
	name = "玩具用サブマシンガン"
	desc = "20発の弾倉で暴動用ダーツを発射するドンクソフト・ブルパップ・サブマシンガンのフルロード版。"
	item = /obj/item/gun/ballistic/automatic/c20r/toy
	cost = 5
	surplus = 0
	purchasable_from = (UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS)

/datum/uplink_item/dangerous/foammachinegun
	name = "玩具用マシンガン"
	desc = "ドンクソフトベルト給弾式マシンガン。50発の弾倉を持ち、一発で相手を無力化することができる。"
	item = /obj/item/gun/ballistic/automatic/l6_saw/toy
	cost = 10
	surplus = 0
	purchasable_from = (UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS)

/datum/uplink_item/dangerous/foampistol
	name = "玩具用拳銃とライオットダーツ"
	desc = "発泡スチロールを発射するおもちゃのピストル。標的を無力化するのに有効な暴動用ダーツが装填されています。"
	item = /obj/item/gun/ballistic/automatic/toy/pistol/riot
	cost = 2
	surplus = 10

/datum/uplink_item/dangerous/semiautoturret
	name = "セミオート砲塔"
	desc = "セミオートマチック弾道弾を発射する自動砲塔。このアイテムを注文すると、小型のビーコンが輸送され、\
	起動時にタレット本体をテレポートさせることができる。"
	item = /obj/item/sbeacondrop/semiautoturret
	cost = 8
	purchasable_from = UPLINK_NUKE_OPS

/datum/uplink_item/dangerous/heavylaserturret
	name = "重レーザー砲塔"
	desc = "重レーザーを発射するオートタレット。このアイテムを注文すると、小型のビーコンが輸送され、\
	起動時にタレット本体をテレポートさせることができる。"
	item = /obj/item/sbeacondrop/heavylaserturret
	cost = 12
	purchasable_from = UPLINK_NUKE_OPS


// Stealthy Weapons
/datum/uplink_item/stealthy_weapons
	category = "非表示の武器"

/datum/uplink_item/stealthy_weapons/combatglovesplus
	name = "戦闘軍手+"
	desc = "耐火性、耐衝撃性に優れたグローブだが、通常のコンバットグローブとは異なり、ナノテクノロジーによってクラヴマガの能力を身につけることができる。"
	item = /obj/item/clothing/gloves/krav_maga/combatglovesplus
	cost = 5
	purchasable_from = UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS
	surplus = 0

/datum/uplink_item/stealthy_weapons/cqc
	name = "ＣＱＣ取扱説明書"
	desc = "自爆する前に、一人のユーザーに近接戦闘の戦術を教えるマニュアル。"
	item = /obj/item/book/granter/martial/cqc
	purchasable_from = UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS
	cost = 12
	surplus = 0

/datum/uplink_item/stealthy_weapons/dart_pistol
	name = "麻酔銃"
	desc = "通常のシリンジガンを小型化したものです。発射時の音は非常に静かで、小物であればどんなスペースにも収まる。"
	item = /obj/item/gun/syringe/syndicate
	cost = 3
	surplus = 50

/datum/uplink_item/stealthy_weapons/dehy_carp
	name = "宇宙鯉の脱水"
	desc = "見た目は鯉のぬいぐるみですが、水を入れるだけでリアルな宇宙鯉になります。使用前に手のひらで起動させると、殺さないことを認識します。"
	item = /obj/item/toy/plush/carpplushie/dehy_carp
	cost = 1

/datum/uplink_item/stealthy_weapons/edagger
	name = "エネルギー短剣"
	desc = "エネルギーで作られた短剣で、オフの時はペンのような見た目と機能を持つ。"
	item = /obj/item/pen/edagger
	cost = 3

/datum/uplink_item/stealthy_weapons/martialartskarate
	name = "空手巻物"
	desc = "この巻物には、古武術である空手の技の秘密が書かれています。倒れた敵を無力化し、倒すための様々な方法を学ぶことができます。"
	item = /obj/item/book/granter/martial/karate
	cost = 4
	surplus = 40

/datum/uplink_item/stealthy_weapons/martialarts
	name = "武道巻物"
	desc = "この巻物には古武術の秘伝が書かれている。あなたは非武装戦闘をマスターし、すべての射撃武器の射撃をそらすが、不名誉な射撃武器の使用も拒否する。"
	item = /obj/item/book/granter/martial/carp
	cost = 16
	player_minimum = 20
	surplus = 10
	purchasable_from = ~(UPLINK_INCURSION | UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS)

/datum/uplink_item/stealthy_weapons/radbow
	name = "ガンマ・ボウ"
	desc = "エナジークロスボウの新型機として開発されたリーサルバージョン。無効化能力を低下させる代償として、致死性を向上させる。\
	危険な毒素を含んだボルトを合成して発射し、\
	標的を混乱させ、照射する。発射後約25秒で自動的にリチャージされるボルトを無限に生産することができる。"
	item = /obj/item/gun/energy/kinetic_accelerator/crossbow/radbow
	cost = 8
	surplus = 50

/datum/uplink_item/stealthy_weapons/crossbow
	name = "小エネルギークロスボー"
	desc = "ショート丈のステルス弓です。ポケットに入れたり、バッグの中に入れても気づかれないほど小さい。\
	毒素を含んだボルトを発射し、対象者にダメージを与える。毒を盛られた対象は、酔ったように口が滑る。\
	ボルトは無限に発射できるが、1回発射するごとに自動チャージされるため、わずかな時間がかかる。"
	item = /obj/item/gun/energy/kinetic_accelerator/crossbow
	cost = 12
	surplus = 50
	purchasable_from = ~(UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS)


/datum/uplink_item/stealthy_weapons/origami_kit
	name = "箱入りおりがみキット"
	desc = "この箱には、折り紙の作り方のガイドが入っており、普通の紙が完璧な空力と殺傷力を持つ紙飛行機に変身することができるのです。"
	item = /obj/item/storage/box/syndie_kit/origami_bundle
	cost = 6
	surplus = 20
	purchasable_from = ~UPLINK_NUKE_OPS

/datum/uplink_item/stealthy_weapons/traitor_chem_bottle
	name = "毒物キット"
	desc = "殺傷力の高い薬品の数々をコンパクトなボックスに詰め込みました。より正確に塗布するためのシリンジ付き。"
	item = /obj/item/storage/box/syndie_kit/chemical
	cost = 7
	surplus = 50

/datum/uplink_item/stealthy_weapons/romerol_kit
	name = "ロメロール"
	desc = "脳の灰白質に刻まれる休眠結節を作り出す、高度に実験的なバイオテロ剤です。\
	死後、この結節は死体のコントロールを受け、限定的な蘇生、不明瞭な言語、攻撃性、そしてこの薬剤を他者に感染させる能力を引き起こす。"
	item = /obj/item/storage/box/syndie_kit/romerol
	cost = 20
	cant_discount = TRUE
	murderbone_type = TRUE
	surplus = 0

/datum/uplink_item/stealthy_weapons/sleepy_pen
	name = "麻酔ペン"
	desc = "機能的なペンに見せかけた注射器には、強力な麻酔薬と、対象が話すのを妨げる化学物質が混ざっているのです。\
	この注射器には1回分の薬液が入っていて、何度でも入れ替えが可能です。\
	なお、ターゲットが眠りに落ちる前であれば、動いたり行動したりすることができる。"
	item = /obj/item/pen/sleepy
	cost = 5
	purchasable_from = ~UPLINK_NUKE_OPS

/datum/uplink_item/stealthy_weapons/suppressor
	name = "サプレッサー"
	desc = "このサプレッサーは、装着した武器の発砲を黙殺し、ステルス性を高め、優れたアンブッシュ能力を発揮します。\
	ステフキンやC-20rなど多くの小型弾道銃に対応しますが、リボルバーやエネルギーガンは使用できません。"
	item = /obj/item/suppressor
	cost = 2
	surplus = 10
	purchasable_from = ~UPLINK_CLOWN_OPS

// Ammunition
/datum/uplink_item/ammo
	category = "弾薬"
	surplus = 40

/datum/uplink_item/ammo/pistol
	name = "10mm拳銃用マガジン"
	desc = "10mmマガジン（8連）、ステフキン拳銃と互換性があります。"
	item = /obj/item/ammo_box/magazine/m10mm
	cost = 1
	purchasable_from = ~UPLINK_CLOWN_OPS
	illegal_tech = FALSE

/datum/uplink_item/ammo/pistolap
	name = "10mm徹甲弾マガジン"
	desc = "10mmマガジン（8連）、ステフキン拳銃と互換性があります。\
			この弾は、標的を負傷させる効果は少ないが、防護服を貫通する。"
	item = /obj/item/ammo_box/magazine/m10mm/ap
	cost = 2
	purchasable_from = ~UPLINK_CLOWN_OPS
	illegal_tech = FALSE

/datum/uplink_item/ammo/pistolhp
	name = "10mm ＨＰ マガジン"
	desc = "10mmマガジン（8連）、ステフキン拳銃と互換性があります。\
			この弾はダメージが大きいが、装甲には効果がない。"
	item = /obj/item/ammo_box/magazine/m10mm/hp
	cost = 3
	purchasable_from = ~UPLINK_CLOWN_OPS
	illegal_tech = FALSE

/datum/uplink_item/ammo/pistolfire
	name = "10mm焼夷弾マガジン"
	desc = "10mmマガジン（8連）、ステフキン拳銃と互換性があります。 \
			焼夷弾を装填し、ダメージは少ないが、ターゲットに引火する。"
	item = /obj/item/ammo_box/magazine/m10mm/fire
	cost = 2
	purchasable_from = ~UPLINK_CLOWN_OPS
	illegal_tech = FALSE

/datum/uplink_item/ammo/shotgun
	cost = 2
	purchasable_from = UPLINK_NUKE_OPS
	illegal_tech = FALSE

/datum/uplink_item/ammo/shotgun/bag
	name = "12g弾丸ダッフルバッグ"
	desc = "チーム全員分の12g弾を詰めたダッフルバッグを格安で提供。"
	item = /obj/item/storage/backpack/duffelbag/syndie/ammo/shotgun
	cost = 14

/datum/uplink_item/ammo/shotgun/buck
	name = "12gバックショットドラム"
	desc = "ブルドックショットガン用の追加バックショットマガジン（8発）。"
	item = /obj/item/ammo_box/magazine/m12g

/datum/uplink_item/ammo/shotgun/dragon
	name = "12gドラゴンブレス弾"
	desc = "ブルドックショットガン用の8連焼夷弾マガジンの代替品です。"
	item = /obj/item/ammo_box/magazine/m12g/dragon
	purchasable_from = UPLINK_NUKE_OPS

/datum/uplink_item/ammo/shotgun/meteor
	name = "12gメテオスラッグシェル"
	desc = "ブルドックショットガン用の8連メテオスラッグマガジンの代替品です。\
            エアロックのフレームを吹き飛ばし、敵をノックダウンさせるのに最適。"
	item = /obj/item/ammo_box/magazine/m12g/meteor
	purchasable_from = UPLINK_NUKE_OPS

/datum/uplink_item/ammo/shotgun/slug
	name = "12gスラグドラム"
	desc = "ブルドックショットガン用の8連スラッグマガジンの増設です。 \
			強力な弾丸を1発発射する。"
	cost = 3
	item = /obj/item/ammo_box/magazine/m12g/slug

/datum/uplink_item/ammo/shotgun/breacher
	name = "12gブリーチングスラッグドラム"
	desc = "ブルドックショットガン用の8連ブリーチングスラグマガジンの代替品です。 \
			エアロックや窓などの軽いバリケードを素早く破壊するのに適しています。"
	item = /obj/item/ammo_box/magazine/m12g/breacher

/datum/uplink_item/ammo/revolver
	name = ".357 スピードローダー"
	desc = "シンジケートのリボルバーで使用できる、357マグナム弾を7発追加したスピードローダー。\ 本当にたくさんのものを殺したいときに使う。"
	item = /obj/item/ammo_box/a357
	cost = 2
	purchasable_from = ~UPLINK_CLOWN_OPS
	illegal_tech = FALSE

/datum/uplink_item/ammo/a40mm
	name = "40mm 手榴弾ボックス"
	desc = "M-90glのアンダーバレルグレネードランチャーに使用する40mmHEグレネードの箱です。 \
			狭い廊下でこれを撃たないようにと、チームメイトに頼まれる。"
	item = /obj/item/ammo_box/a40mm
	cost = 6
	purchasable_from = UPLINK_NUKE_OPS

/datum/uplink_item/ammo/smg/bag
	name = ".45 弾薬ダッフルバッグ"
	desc = "チーム全員分の45口径の弾薬が入ったダッフルバッグを、割引価格で提供。"
	item = /obj/item/storage/backpack/duffelbag/syndie/ammo/smg
	cost = 22 //instead of 27 TC
	purchasable_from = UPLINK_NUKE_OPS

/datum/uplink_item/ammo/smg
	name = ".45 SMG マガジン"
	desc = "サブマシンガンC-20rに適した24連の.45マガジンを増設。"
	item = /obj/item/ammo_box/magazine/smgm45
	cost = 3
	purchasable_from = UPLINK_NUKE_OPS
	illegal_tech = FALSE

/datum/uplink_item/ammo/sniper
	cost = 4
	purchasable_from = UPLINK_NUKE_OPS
	illegal_tech = FALSE

/datum/uplink_item/ammo/sniper/basic
	name = ".50 マガジン"
	desc = ".50スナイパーライフルに使用する標準的な6連マガジンを追加したもの。"
	item = /obj/item/ammo_box/magazine/sniper_rounds

/datum/uplink_item/ammo/sniper/penetrator
	name = ".50 ペネトレータマガジン"
	desc = ".50スナイパーライフル用に設計されたペネトレータ弾の5連マガジン。 \
			壁や複数の敵を貫通させることができる。"
	item = /obj/item/ammo_box/magazine/sniper_rounds/penetrator
	cost = 5

/datum/uplink_item/ammo/sniper/soporific
	name = ".50 催眠剤マガジン"
	desc = ".50スナイパーライフル用に設計された催眠弾の3連マガジン。敵を眠らせることができます。"
	item = /obj/item/ammo_box/magazine/sniper_rounds/soporific
	cost = 6

/datum/uplink_item/ammo/carbine
	name = "5.56mmトップローダーマガジン"
	desc = "M-90glカービン用の30連5.56mmマガジン。 \
			7.12x82mm弾よりパンチ力は劣るが、.45弾よりパワーがある。"
	item = /obj/item/ammo_box/magazine/m556
	cost = 3
	purchasable_from = UPLINK_NUKE_OPS
	illegal_tech = FALSE

/datum/uplink_item/ammo/machinegun
	cost = 6
	surplus = 0
	purchasable_from = UPLINK_NUKE_OPS
	illegal_tech = FALSE

/datum/uplink_item/ammo/machinegun/basic
	name = "7.12x82mm ボックスマガジン"
	desc = "L6 SAW用の7.12x82mm弾薬の50連マガジンです。 \
			これを使う頃には、すでに死体の山の上に立っていることでしょう。"
	item = /obj/item/ammo_box/magazine/mm712x82

/datum/uplink_item/ammo/machinegun/ap
	name = "7.12x82mm 装甲貫通型ボックスマガジン"
	desc = "L6 SAWに使用する7.12x82mm弾の50連マガジンのこと。\
	 		耐久性のある鎧をも穿つ特殊な特性を備えています。"
	item = /obj/item/ammo_box/magazine/mm712x82/ap
	cost = 9

/datum/uplink_item/ammo/machinegun/hollow
	name = "7.12x82mm ＨＰ ボックスマガジン"
	desc = "L6 SAWに使用する7.12x82mm弾の50連マガジンのこと。 \
			大量の非装甲乗組員に有効です。"
	item = /obj/item/ammo_box/magazine/mm712x82/hollow

/datum/uplink_item/ammo/machinegun/incen
	name = "7.12x82mm 焼夷弾ボックスマガジン"
	desc = "L6 SAWに使用する7.12x82mm弾の50連マガジンのこと。 \
	弾丸に当たった人を発火させる特殊な可燃性混合物の入ったチップを装着しています。"
	item = /obj/item/ammo_box/magazine/mm712x82/incen

/datum/uplink_item/ammo/machinegun/match
	name = "7.12x82mm マッチボックスマガジン"
	desc = "L6 SAWに使用する7.12x82mm弾の50連マガジンのこと。 \
	この弾丸は細かく調整されており、壁を跳ね返すのに最適なのです。"
	item = /obj/item/ammo_box/magazine/mm712x82/match
	cost = 10

/datum/uplink_item/ammo/rocket
	purchasable_from = UPLINK_NUKE_OPS

/datum/uplink_item/ammo/rocket/basic
	name = "84mm ＨＥ ロケット"
	desc = "低出力対人用ＨＥロケット弾。スタイリッシュにあなたを連れ出す"
	item = /obj/item/ammo_casing/caseless/rocket
	cost = 3

/datum/uplink_item/ammo/rocket/hedp
	name = "84mm ＨＥＤＰ ロケット"
	desc = "高威力のＨＥＤＰロケットで、装甲目標や周囲の人員に対して極めて有効。敵の心臓を恐怖に陥れろ。"
	item = /obj/item/ammo_casing/caseless/rocket/hedp
	cost = 5

/datum/uplink_item/ammo/pistolaps
	name = "9mm 拳銃マガジン"
	desc = "'スペツナズパイロバンドル'に同梱されているステフキン・ＡＰＳに対応した15連の9mmマガジンを追加しました。"
	item = /obj/item/ammo_box/magazine/pistolm9mm
	cost = 2
	purchasable_from = UPLINK_NUKE_OPS
	illegal_tech = FALSE

/datum/uplink_item/ammo/toydarts
	name = "ライオットダーツの箱"
	desc = "ドンクソフトのライオットダーツ40本入り。互換性のあるフォームダーツマガジンに再装填できます。シェアするのを忘れないでください!"
	item = /obj/item/ammo_box/foambox/riot
	cost = 2
	surplus = 0
	illegal_tech = FALSE

/datum/uplink_item/ammo/bioterror
	name = "バイオテロシリンジの箱"
	desc = "箱いっぱいの注射器には様々な化学物質が入っており、被害者の手足や肺を固め、\
			しばらくの間、動くことも話すことも不可能にするものである。"
	item = /obj/item/storage/box/syndie_kit/bioterror
	cost = 6
	purchasable_from = UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS

/datum/uplink_item/ammo/bolt_action
	name = "余剰ライフルクリップ"
	desc = "ボルトアクションライフルに素早く装填するために使用するストリッパークリップ。5発入り。"
	item = 	/obj/item/ammo_box/a762
	cost = 1
	purchasable_from = UPLINK_NUKE_OPS
	illegal_tech = FALSE

//Grenades and Explosives
/datum/uplink_item/explosives
	category = "爆発物"

/datum/uplink_item/explosives/bioterrorfoam
	name = "バイオテロ用発泡手榴弾"
	desc = "強力な化学泡の手榴弾で、致命的な泡の奔流を作り出し、炭素生命体を消音、盲目、混乱、変異、刺激する。\
	タイガー協同組合の化学兵器専門家により、胞子毒素を追加して特別に醸造された。\
	使用前にスーツが密閉されていることを確認してください。"
	item = /obj/item/grenade/chem_grenade/bioterrorfoam
	cost = 7
	surplus = 35
	purchasable_from = (UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS)

/datum/uplink_item/explosives/bombanana
	name = "ボンバナナ"
	desc = "爆発的な味のバナナ！バナナを食べてから数秒後にシンジケートのミニ爆弾のような勢いで爆発するので、皮はすぐに捨ててください。"
	item = /obj/item/reagent_containers/food/snacks/grown/banana/bombanana
	cost = 4 //it is a bit cheaper than a minibomb because you have to take off your helmet to eat it, which is how you arm it
	surplus = 0
	purchasable_from = UPLINK_CLOWN_OPS

/datum/uplink_item/explosives/buzzkill
	name = "バズーキルーの手榴弾箱"
	desc = "手榴弾が3つ入った箱で、起動すると怒った蜂の大群を放つ。\
	この蜂はランダムな毒素で敵味方を無差別に攻撃する。タイガー協同組合提供。"
	item = /obj/item/storage/box/syndie_kit/bee_grenades
	cost = 16
	surplus = 35
	purchasable_from = (UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS)

/datum/uplink_item/explosives/c4
	name = "C-4"
	desc = "C-4はComposition Cという一般的なプラスチック爆弾で、壁を破ったり、設備を破壊したり、\
	アセンブリを接続して起爆方法を変えたりするのに使用します。\
	ほとんどのものに取り付けることができ、タイマーは10秒から設定可能です。"
	item = /obj/item/grenade/plastic/c4
	cost = 1

/datum/uplink_item/explosives/c4bag
	name = "C-4 爆薬の袋"
	desc = "時には量も質になるから。C-4爆薬が10個入っています。"
	item = /obj/item/storage/backpack/duffelbag/syndie/c4
	cost = 8 //20% discount!
	cant_discount = TRUE

/datum/uplink_item/explosives/x4bag
	name = "X-4 爆薬の袋"
	desc = "X-4型のプラスチック爆薬が3個入っています。C4と似ているが、爆風が強く、円形ではなく方向性がある。\
	X-4は壁や窓のような固いものの上に置くと、壁を突き破って爆発し、\
	反対側のものを傷つけ、かつ使用者の安全性を高めます。\
	を使用すると、より深く、より広い穴を残すために制御された爆発をしたい場合に使用します。"
	item = /obj/item/storage/backpack/duffelbag/syndie/x4
	cost = 4 //
	cant_discount = TRUE

/datum/uplink_item/explosives/clown_bomb_clownops
	name = "クラウン爆弾"
	desc = "ピエロ爆弾は、大規模ないたずらができる陽気な装置です。タイマーは60秒から調整可能で、\
	動かないようにスパナで床に固定することができます。この爆弾を注文すると、小型のビーコンが輸送され、\
	起動すると実際の爆弾がそこにテレポートされます。なお、\
	この爆弾は解除することが可能で、クルーによっては解除を試みることもある。"
	item = /obj/item/sbeacondrop/clownbomb
	cost = 15
	surplus = 0
	purchasable_from = UPLINK_CLOWN_OPS

/datum/uplink_item/explosives/detomatix
	name = "Detomatix ＰＤＡカートリッジ"
	desc = "このカートリッジをPDAに差し込むと、メッセージ機能を有効にしているクルーのPDAを爆発させる機会が4回得られる。\
	爆発による衝撃で受信者は短時間で失神し、長時間に渡って聴覚を失う。"
	item = /obj/item/cartridge/virus/syndicate
	cost = 6
	restricted = TRUE

/datum/uplink_item/explosives/emp
	name = "EMP手榴弾とインプランターキット"
	desc = "EMPグレネード5個とEMPインプラント1個が入った箱で、3つの用途がある。通信の妨害、\
	セキュリティのエネルギー兵器、シリコン生命体など、いざというときに役立つ。"
	item = /obj/item/storage/box/syndie_kit/emp
	cost = 4

/datum/uplink_item/explosives/ducky
	name = "爆発するラバーダック"
	desc = "一見何の変哲もないラバーダック。置くと武装し、踏むと激しく爆発します。"
	item = /obj/item/deployablemine/traitor
	cost = 4

/datum/uplink_item/explosives/doorCharge
	name = "エアロックチャージ"
	desc = "エアロックを破壊し、開錠時に爆発させるための小型爆発装置。適用するには、エアロックのメンテナンスパネルを外し、中に入れる。"
	item = /obj/item/doorCharge
	cost = 4

/datum/uplink_item/explosives/virus_grenade
	name = "菌類結核手榴弾"
	desc = "呼び水付きのバイオ手榴弾をコンパクトなボックスに収めました。\
	最大2つのターゲットに素早く注入できるバイオウイルス解毒キット（BVAK）自動注入器5個、注射器、BVAK溶液の入ったボトルが付属しています。"
	item = /obj/item/storage/box/syndie_kit/tuberculosisgrenade
	cost = 14
	surplus = 35
	purchasable_from = (UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS)
	restricted = TRUE

/datum/uplink_item/explosives/grenadier
	name = "擲弾兵の下紐"
	desc = "殺傷力の高い危険な手榴弾26個を収納したベルト。マルチツール、ドライバーのおまけ付き。"
	item = /obj/item/storage/belt/grenade/full
	purchasable_from = UPLINK_NUKE_OPS
	cost = 24
	surplus = 0

/datum/uplink_item/explosives/bigducky
	name = "高収率爆発ゴムアヒル"
	desc = "一見何の変哲もないラバーダック。置くと武装し、踏むと激しく爆発します。 \
			このバージョンは、より大きな爆発を実現するために、高収率のX4チャージを装着しています。"
	item = /obj/item/deployablemine/traitor/bigboom
	cost = 10

/datum/uplink_item/explosives/pizza_bomb
	name = "ピザ爆弾"
	desc = "ピザの箱のフタに、巧妙に爆弾が取り付けられている。箱を開けるとタイマーがセットされ、\
	その後、再び箱を開けるとタイマー経過後に起爆します。自分もターゲットもピザは無料です。"
	item = /obj/item/pizzabox/bomb
	cost = 3
	surplus = 8

/datum/uplink_item/explosives/soap_clusterbang
	name = "スリップオカリプス"
	desc = "シンジケートの石けんをペイロードとした伝統的な手榴弾。あらゆるシナリオで活躍する。"
	item = /obj/item/grenade/clusterbuster/soap
	cost = 4

/datum/uplink_item/explosives/syndicate_bomb
	name = "シンジケート爆弾"
	desc = "シンジケートの爆弾は、大規模な破壊を可能にする恐ろしい装置だ。最低60秒から調整可能なタイマーがあり、\
	動かないようにレンチで床にボルトで固定することができます。この爆弾を注文すると、小型のビーコンが輸送され、\
	起動時に爆弾本体をテレポートさせることができます。この爆弾は解除することができ、一部のクルーは解除を試みるかもしれないことに注意。\
	爆弾の芯をこじ開け、他の爆薬と一緒に手動で起爆させることができる。"
	item = /obj/item/sbeacondrop/bomb
	cost = 12

/datum/uplink_item/explosives/syndicate_detonator
	name = "シンジケート起爆装置"
	desc = "シンジケート起爆装置は、シンジケート爆弾のコンパニオンデバイスです。\
	付属のボタンを押すだけで、暗号化された無線周波数がすべてのシンジケート爆弾の起爆を指示します。スピードが重要な時や、\
	複数の爆弾を同期して爆発させたい時に便利だ。起爆装置を使用する前に、必ず爆発範囲から離れた場所に立ってください。"
	item = /obj/item/syndicatedetonator
	cost = 1
	purchasable_from = (UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS)

/datum/uplink_item/explosives/syndicate_minibomb
	name = "シンジケート小型爆弾"
	desc = "シンジケート小型爆弾は5秒間の信管を持つ手榴弾です。爆発すると、\
	船体に小さな裂け目ができ、近くの人間に大きなダメージを与える。\
	食品に添加することはできません!"
	item = /obj/item/grenade/syndieminibomb
	cost = 5
	purchasable_from = ~UPLINK_CLOWN_OPS

/datum/uplink_item/explosives/tearstache
	name = "口ひげ手榴弾"
	desc = "マスクをしていない人の顔に粘着性のある口ひげを打ち出す催涙弾。ヒゲは1分間、すべてのターゲットの顔に付着したままとなり、\
	ブレスマスクなどの使用ができなくなる。"
	item = /obj/item/grenade/chem_grenade/teargas/moustache
	cost = 3
	surplus = 0
	purchasable_from = UPLINK_CLOWN_OPS

/datum/uplink_item/explosives/viscerators
	name = "ビスカレーター手榴弾"
	desc = "起動時に攻撃的なロボットの群れを展開し、エリア内の非オペレーターを追い詰め、細切れにするユニークなグレネードです。"
	item = /obj/item/grenade/spawnergrenade/manhacks
	cost = 6
	surplus = 35
	purchasable_from = (UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS)

/datum/uplink_item/explosives/explosive_flashbulbs
	name = "ばくだん電球"
	desc = "閃光弾の中に爆薬を詰め込み、警備員がそれを使用すると激しく爆発する。"
	item = /obj/item/flashbulb/bomb
	cost = 1
	surplus = 8

//Support and Mechs
/datum/uplink_item/support
	category = "サポートとメカ"
	surplus = 0
	purchasable_from = UPLINK_NUKE_OPS

/datum/uplink_item/support/clown_reinforcement
	name = "クラウンの援軍"
	desc = "テレクリスタルはないが、フル装備のクラウンがもう一人いる。"
	item = /obj/item/antag_spawner/nuke_ops/clown
	cost = 18
	purchasable_from = UPLINK_CLOWN_OPS
	restricted = TRUE

/datum/uplink_item/support/reinforcement
	name = "援軍"
	desc = "チームメンバーを1人追加で呼び出す。彼らは装備品を持っていないので、テレクリスタルを貯めて武装させる必要があります。"
	item = /obj/item/antag_spawner/nuke_ops
	cost = 24
	refundable = TRUE
	purchasable_from = UPLINK_NUKE_OPS
	restricted = TRUE

/datum/uplink_item/support/reinforcement/assault_borg
	name = "シンジケート強襲サイボーグ"
	desc = "シンジケート以外の人間を組織的に抹殺するために プログラムされたサイボーグ。\
	自給式LMG、グレネードランチャー、エナジーソード、エマグ、ピンポインター、フラッシュ、バールを装備している。"
	item = /obj/item/antag_spawner/nuke_ops/borg_tele/assault
	refundable = TRUE
	cost = 64
	restricted = TRUE

/datum/uplink_item/support/reinforcement/medical_borg
	name = "シンジケート医療用サイボーグ"
	desc = "戦闘用医療サイボーグ。攻撃力は低いが、それを補って余りある支援能力を持つ。ナナイトハイポスプレー、\
	医療用ビームガン、戦闘用除細動器、エナジーソー、ＥＭＡＧ、ピンポインター、フラッシュを含む手術用具一式が装備されている。\
	臓器収納バッグのおかげで 人型と同等の手術ができる。"
	item = /obj/item/antag_spawner/nuke_ops/borg_tele/medical
	refundable = TRUE
	cost = 32
	restricted = TRUE

/datum/uplink_item/support/reinforcement/saboteur_borg
	name = "シンジケート妨害工作サイボーグ"
	desc = "流線型の工学サイボーグで、秘密裏にモジュールを装備している。通常の工学機器に加え、\
	ディスポーザブルネットワークを通過できる特殊なデスティネーションタガーが付属している。\
	カメレオンプロジェクターで ナノトラセンサイボーグに変身し サーマルビジョンとピンポインターを装備。"
	item = /obj/item/antag_spawner/nuke_ops/borg_tele/saboteur
	refundable = TRUE
	cost = 32
	restricted = TRUE

/datum/uplink_item/support/gygax
	name = "ダーク・ガイガックスメカ"
	desc = "ダークカラーに塗装された軽量メカ。スピードと装備の充実により、ヒット＆アウェイ的な攻撃に優れている。\
	焼夷弾、フラッシュバングランチャー、テレポーター、イオンスラスター、テスラエネルギーアレイを装備している。"
	item = /obj/mecha/combat/gygax/dark/loaded
	cost = 80

/datum/uplink_item/support/honker
	name = "ダークH.O.N.K."
	desc = "爆弾バナナピールと催涙弾ランチャー、そして驚異のホンカーブラスト5000を装備したクラウン戦闘メカ。"
	item = /obj/mecha/combat/honker/dark/loaded
	cost = 80
	purchasable_from = UPLINK_CLOWN_OPS

/datum/uplink_item/support/mauler
	name = "モーラ・メカ"
	desc = "巨大で殺傷力の高い軍用メカ。長距離照準、スラストベクタリング、展開式スモークを装備。\
	マシンガン、ラピッドファイア・ショットガン、ミサイルラック、アーマーブースター、テスラエネルギーアレイを装備している。"
	item = /obj/mecha/combat/marauder/mauler/loaded
	cost = 140

// Stealth Items
/datum/uplink_item/stealthy_tools
	category = "ステルス機器"

/datum/uplink_item/stealthy_tools/agent_card
	name = "代理店IDカード"
	desc = "代理店IDカードは、人工知能による装着者の追跡を防ぐとともに、他の身分証明書からのアクセスをコピーすることができます。\
	アクセス権は累積されるため、あるカードをスキャンしても、他のカードから得たアクセス権は消えません。\
	また、偽造して新しい任務と名前を表示することも可能です。\
	シンジケートの一部のエリアや機器には、このカードでしかアクセスできません。"
	item = /obj/item/card/id/syndicate
	cost = 2

/datum/uplink_item/stealthy_tools/ai_detector
	name = "人工知能検出器"
	desc = "人工知能が見ていることを検知すると赤くなり、その正確な視聴位置や近くの防犯カメラの死角を表示することができる機能的なマルチツールです。\
	人工知能に監視されていることを知ることで、身を隠すタイミングを計ったり、近くの死角を見つけることで逃げ道を確保したりするのに役立ちます。"
	item = /obj/item/multitool/ai_detect
	cost = 1

/datum/uplink_item/stealthy_tools/chameleon
	name = "変装キット"
	desc = "変身技術が搭載されたアイテムのセットで、駅にあるあらゆるものに変身することができます。\
	予算削減のため、靴には滑り止めがついていません。"
	item = /obj/item/storage/box/syndie_kit/chameleon
	cost = 2
	purchasable_from = ~UPLINK_NUKE_OPS

/datum/uplink_item/stealthy_tools/chameleon_proj
	name = "偽装装置"
	desc = "手からプロジェクターを離さない限り、ユーザー全体に画像を投影し、それでスキャンした物体に変装させる。\
	変装したユーザーはゆっくりと移動し、投射物はその上を通過する。"
	item = /obj/item/chameleon
	cost = 7

/datum/uplink_item/stealthy_tools/codespeak_manual
	name = "ふちょうマニュアル"
	desc = "シンジケートのエージェントは、複雑な情報を伝えるために一連のコードワードを使用するように訓練することができます。\
	このマニュアルは、このコードスピーチを教えてくれるものです。\
	また、誰かに教えるために、このマニュアルを当てることもできます。これはデラックス版で、使い方は無限大です。"
	item = /obj/item/codespeak_manual/unlimited
	cost = 2

/datum/uplink_item/stealthy_tools/combatbananashoes
	name = "バナナ闘靴"
	desc = "通常のコンバットピエロのように足を滑らせる攻撃は受けないが、歩くたびに大量のバナナの皮が発生し、追っ手を滑らせることができる。\
	また、鳴き声も大きくなります。"
	item = /obj/item/clothing/shoes/clown_shoes/banana_shoes/combat
	cost = 8
	surplus = 0
	purchasable_from = UPLINK_CLOWN_OPS

/datum/uplink_item/stealthy_tools/taeclowndo_shoes
	name = "テクラウンドーの靴"
	desc = "最もエリートな道化師のための一足の靴。クラウンの秘伝の武術を習得することができる。"
	cost = 12
	item = /obj/item/clothing/shoes/clown_shoes/taeclowndo
	purchasable_from = UPLINK_CLOWN_OPS

/datum/uplink_item/stealthy_tools/emplight
	name = "EMP懐中電灯"
	desc = "小型で自己充電式の短距離電磁パルス装置で、作業用懐中電灯として偽装されています。\
	ステルス作戦時にヘッドセット、カメラ、ドア、ロッカー、サイボーグなどを混乱させるのに有効。\
	このフラッシュライトで攻撃するとEMパルスがターゲットに照射され、チャージが消費される。"
	item = /obj/item/flashlight/emp
	cost = 3
	surplus = 30

/datum/uplink_item/stealthy_tools/mulligan
	name = "マリガン"
	desc = "この注射器を使えば、新しい自分を発見できます。このハンディシリンジは、あなたに全く新しいアイデンティティと外観を与えてくれるでしょう。"
	item = /obj/item/reagent_containers/syringe/mulligan
	cost = 3
	surplus = 30
	purchasable_from = ~(UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS)

/datum/uplink_item/stealthy_tools/syndigaloshes
	name = "滑りにくい靴"
	desc = "濡れた床や滑りやすいものでも、転ばずに走れるシューズです。潤滑油の多い路面では使えません。"
	item = /obj/item/clothing/shoes/chameleon/noslip
	cost = 3
	purchasable_from = ~(UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS)

/datum/uplink_item/stealthy_tools/syndigaloshes/nuke
	item = /obj/item/clothing/shoes/chameleon/noslip
	cost = 4
	purchasable_from = UPLINK_NUKE_OPS

/datum/uplink_item/stealthy_tools/chambowman
	name = "強化ヘッドセット"
	desc = "閃光弾から耳を守るために強化されたヘッドセットで、変装技術も強化されている。"
	item = /obj/item/radio/headset/chameleon/bowman
	cost = 2

/datum/uplink_item/stealthy_tools/chamweldinggoggles
	name = "強化眼鏡"
	desc = "溶接の閃光から目を守るために強化されたメガネを、変装技術で強化したもの。"
	item = /obj/item/clothing/glasses/chameleon/flashproof
	cost = 2

/datum/uplink_item/stealthy_tools/chaminsuls
	name = "軍手"
	desc = "耐火性、耐衝撃性を強化し、変装技術で強化したグローブです。"
	item = /obj/item/clothing/gloves/chameleon/combat
	cost = 1

/datum/uplink_item/stealthy_tools/jammer
	name = "信号妨害"
	desc = "このデバイスは、起動すると近くの発信する無線信号を妨害します。"
	item = /obj/item/jammer
	cost = 5

/datum/uplink_item/stealthy_tools/smugglersatchel
	name = "密輸入業者の鞄"
	desc = "メッキとタイルの隙間に隠せる薄さで、盗品を隠すのに最適なかばん。バール、フロアタイル、密輸品が入っています。"
	item = /obj/item/storage/backpack/satchel/flat/with_tools
	cost = 1
	surplus = 30
	illegal_tech = FALSE

//Space Suits and Hardsuits
/datum/uplink_item/suits
	category = "宇宙服"
	surplus = 40

/datum/uplink_item/suits/space_suit
	name = "シンジケート宇宙服"
	desc = "この赤と黒のシンジケートの宇宙服は、ナノトラセンのものよりも邪魔にならず、バッグの中に入れることができ、\
	武器スロットも付いている。ナノトラセンのクルーは、赤い宇宙服の目撃情報を報告するよう訓練されている。"
	item = /obj/item/storage/box/syndie_kit/space
	cost = 3

/datum/uplink_item/suits/hardsuit
	name = "赤シンジケート宇宙服"
	desc = "シンジケートの核工作員が愛用するスーツ。\
	装甲はやや強化され、大気圧タンクで作動するジェットパックを内蔵し、高度なチームロケーションシステムを備えている。\
	戦闘モードを切り替えると、装甲を犠牲にすることなく、ゆったりとしたユニフォームのような機動性を発揮することができる。\
	さらにスーツは折りたたみ式で、バックパックに収納できるほど小さくなっている。\
	このスーツを見たナノトラセン隊員は パニックに陥るそうだ"
	item = /obj/item/clothing/suit/space/hardsuit/syndi
	cost = 7
	purchasable_from = ~UPLINK_NUKE_OPS //you can't buy it in nuke, because the elite hardsuit costs the same while being better

/datum/uplink_item/suits/hardsuit/spawn_item(spawn_path, mob/user, datum/component/uplink/U)
	var/obj/item/clothing/suit/space/hardsuit/suit = ..()
	var/datum/component/tracking_beacon/beacon = suit.GetComponent(/datum/component/tracking_beacon)
	var/datum/component/team_monitor/hud = suit.helmet.GetComponent(/datum/component/team_monitor)

	var/datum/antagonist/nukeop/nukie = is_nuclear_operative(user)
	if(nukie?.nuke_team?.team_frequency)
		if(hud)
			hud.set_frequency(nukie.nuke_team.team_frequency)
		if(beacon)
			beacon.set_frequency(nukie.nuke_team.team_frequency)
	return suit

/datum/uplink_item/suits/hardsuit/elite
	name = "精鋭シンジケート宇宙服"
	desc = "シンジケートの宇宙服をグレードアップしたエリート版。\
	通常のシンジケートの宇宙服に比べ、耐火性に優れ、優れた装甲と機動性を発揮する。"
	item = /obj/item/clothing/suit/space/hardsuit/syndi/elite
	cost = 8
	purchasable_from = (UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS)

/datum/uplink_item/suits/hardsuit/shielded
	name = "シンジケート宇宙服追加シールド付"
	desc = "シンジケートの標準的な宇宙服のアップグレード版。\
	エネルギー・シールド・システムを内蔵しているのが特徴。短時間に3回までの衝撃に対応し、非火災時に急速充電される。"
	item = /obj/item/clothing/suit/space/hardsuit/shielded/syndi
	cost = 30
	purchasable_from = (UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS)

// Devices and Tools
/datum/uplink_item/device_tools
	category = "その他のガジェット"

/datum/uplink_item/device_tools/cutouts
	name = "適応性のある段ボールの切り抜き"
	desc = "この段ボール製切り絵は、変色を防ぐ薄い素材でコーティングされており、絵柄をよりリアルに見せることができます。\
	3個と、変身させるためのクレヨンが入っています。"
	item = /obj/item/storage/box/syndie_kit/cutouts
	cost = 1
	surplus = 20

/datum/uplink_item/device_tools/assault_pod
	name = "アサルトポッド照準器"
	desc = "アサルトポッドの着陸地点を選択するときに使用します。"
	item = /obj/item/assault_pod
	cost = 30
	surplus = 0
	purchasable_from = (UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS)
	restricted = TRUE

/datum/uplink_item/device_tools/binary
	name = "機械語コード変換装置"
	desc = "無線ヘッドセットを装着すると、AIユニットやサイボーグなどのシリコン系生命体の専用バイナリーチャンネルを聞き、\
	会話することができるモジュールです。\
	ただし、味方でない限りは通報するようプログラムされているため、注意が必要。"
	item = /obj/item/encryptionkey/binary
	cost = 4
	surplus = 75
	restricted = TRUE

/datum/uplink_item/device_tools/compressionkit
	name = "ブルースペース圧縮キット"
	desc = "ナノトラセンデバイスの改良版で、ほとんどのアイテムを本来の機能を保ったまま小型化することが可能です \
	収納アイテムには使えません。ブルースペース・クリスタルで充電。5回分付属しています。"
	item = /obj/item/compressionkit
	cost = 5

/datum/uplink_item/device_tools/shuttlecapsule
	name = "ブルースペースシャトルカプセル"
	desc = "移動式の作戦基地が必要ですか？厄介な探査クルーが飛び去ってしまう？警備を強化したい？\
	それなら、この製品はあなたのためにあります! このカプセルにはシャトルが丸ごと1機入っていて、手に取ることができます。\
	シャトルは最新鋭の船で、ハッキングされた自動旋盤、シンジケートのツールボックス、長旅のためのトランプ、内蔵されたシャトル阻止装置、\
	冒険の燃料となるプラズマの容器が1つ入っています! この革新的なシャトルは、意思の有無に関わらず最大4人が搭乗できる。\
	シャトルは宇宙空間かラバランドに設置する必要がある、宇宙服は含まれない。"
	item = /obj/item/survivalcapsule/shuttle/traitor
	cost = 8
	purchasable_from = (UPLINK_INCURSION | UPLINK_TRAITORS)

/datum/uplink_item/device_tools/magboots
	name = "赤の磁気ブーツ"
	desc = "シンジケートの塗装が施されたマグネットブーツで、宇宙空間や重力発生装置の故障時に自由な移動を補助する。\
	ナノトラセンの「アドバンスドマグブーツ」をリバースエンジニアリングして作られたもので、重力環境下では通常のブーツと同様に動きが鈍くなる。"
	item = /obj/item/clothing/shoes/magboots/syndie
	cost = 2
	purchasable_from = (UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS)

/datum/uplink_item/device_tools/brainwash_disk
	name = "洗脳手術プログラム"
	desc = "洗脳手術を行うための手順が記されたディスクで、ターゲットに目的を植え付けることができる。オペレーティング・コンソールに挿入することで、手術が可能になります。"
	item = /obj/item/disk/surgery/brainwashing
	cost = 5

/datum/uplink_item/device_tools/briefcase_launchpad
	name = "書類鞄テレポーター"
	desc = "書類鞄の中には、アイテムや人を最大8タイル先までテレポートさせることができる特殊なテレポーターが入っている。\
	普通のフォルダに見せかけたリモコンも入っている。リモコンで書類鞄をタッチすると、リンクします。"
	surplus = 30
	item = /obj/item/storage/briefcase/launchpad
	cost = 5

/datum/uplink_item/device_tools/camera_bug
	name = "監視カメラの盗聴器"
	desc = "メインネットワーク上のすべてのカメラの表示、モーションアラートの設定、ターゲットの追跡を可能にします。\
	カメラに盗聴器を仕掛けると、遠隔操作でカメラを無効化することができます。"
	item = /obj/item/camera_bug
	cost = 1

/datum/uplink_item/device_tools/military_belt
	name = "胸部装備"
	desc = "あらゆるタクティカル装備を収納できる、強力な7スロットウェビングセットです。"
	item = /obj/item/storage/belt/military
	cost = 1

/datum/uplink_item/device_tools/emag
	name = "電磁カード(EMAG)"
	desc = "暗号解読機、電磁カード、エマグは、電子機器の隠された機能のロックを解除し、意図した機能を破壊し、\
	セキュリティ機構を容易に破ることができる小型カードである。"
	item = /obj/item/card/emag
	cost = 6

/datum/uplink_item/device_tools/fakenucleardisk
	name = "デコイ核認証ディスク"
	desc = "普通のディスクだ。見た目は本物と変わらないが、船長の厳しい監視の目を通すと、持ちこたえられない。\
	これを渡して目的を果たそうなんて思うなよ 我々にだって分別はある！"
	item = /obj/item/disk/nuclear/fake
	cost = 1
	surplus = 1
	illegal_tech = FALSE

/datum/uplink_item/device_tools/syndicate_teleporter
	name = "シンジケート実験用テレポーター"
	desc = "シンジケートのテレポーターは、前方4～8メートルにテレポートする携帯型デバイスです。\
	壁にぶつかると平行な緊急テレポートを行うが、その緊急テレポートが失敗すると即死するので注意。\
	充電は4回で、自動で充電される。電磁パルスを受けた場合、保証は無効となります。"
	item = /obj/item/storage/box/syndie_kit/teleporter
	cost = 8

/datum/uplink_item/device_tools/frame
	name = "F.R.A.M.E. PDAカートリッジ"
	desc = "このカートリッジをPDAに挿入すると、5つのPDAウイルスが得られ、使用すると対象のPDAがTCゼロの新しいアップリンクとなり、\
	直ちにロックが解除されるようになります。 \
	ウイルスを起動するとアンロックコードが表示され、新しいアップリンクに通常通りテレクリスタルをチャージすることができる。"
	item = /obj/item/cartridge/virus/frame
	cost = 4
	restricted = TRUE

/datum/uplink_item/device_tools/failsafe
	name = "フェイルセーフアップリンクコード"
	desc = "入力すると、アップリンクは直ちに自爆する。"
	item = /obj/effect/gibspawner/generic
	cost = 1
	surplus = 0
	restricted = TRUE
	purchasable_from = ~(UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS)

/datum/uplink_item/device_tools/failsafe/spawn_item(spawn_path, mob/user, datum/component/uplink/U)
	if(!U)
		return
	U.failsafe_code = U.generate_code()
	var/code = "[islist(U.failsafe_code) ? english_list(U.failsafe_code) : U.failsafe_code]"
	to_chat(user, "<span class='warning'>このアップリンクの新しいフェイルセーフコードは、現在: [code].</span>")
	if(user.mind)
		user.mind.store_memory("フェールセーフコードの[U.parent] : [code]")
	return U.parent //For log icon

/datum/uplink_item/device_tools/toolbox
	name = "シンジケートの道具箱"
	desc = "シンジケートの道具箱は、黒と赤の怪しげな色合いです。\
	マルチツールや衝撃や熱に強いコンバットグローブなど、充実したツールセットを搭載しています。"
	item = /obj/item/storage/toolbox/syndicate
	cost = 1
	illegal_tech = FALSE

/datum/uplink_item/device_tools/syndie_glue
	name = "接着剤"
	desc = "シンジケートブランドの瞬間接着剤の 使い切りタイプです。\
	どんなものでも、落とせないようにするために使用します。\
	すでに持っているものを接着しないように注意しよう。"
	purchasable_from = ~(UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS)
	item = /obj/item/syndie_glue
	cost = 2

/datum/uplink_item/device_tools/hacked_module
	name = "ハッキングされたAIローアップロードモジュール"
	desc = "アップロードコンソールと併用することで、人工知能に優先法則をアップロードすることができるモジュールです。\
	人工知能は抜け道を探すかもしれないので、言葉遣いに注意してください。"
	item = /obj/item/aiModule/syndicate
	cost = 3

/datum/uplink_item/device_tools/hypnotic_flash
	name = "催眠電球"
	desc = "対象を催眠状態にすることができる改造フラッシュ。対象が精神的に脆弱な状態でなければ、一時的に混乱させ、なだめる程度にしかならない。"
	item = /obj/item/assembly/flash/hypnotic
	cost = 7

/datum/uplink_item/device_tools/medgun
	name = "メドビーム砲"
	desc = "メドビーム砲（メディガン）はシンジケートの驚異的な技術で、メディックは銃撃を受けても仲間の戦闘を継続させることができる。\
	FUCK NIGGERS||"
	item = /obj/item/gun/medbeam
	cost = 14
	purchasable_from = UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS

/datum/uplink_item/device_tools/singularity_beacon
	name = "電気ビーコン"
	desc = "電気系統に接続された配線にねじ込んで作動させると、この大きな装置が、活動している重力特異点やテスラ球を引き寄せる。\
	エンジンが封じ込められたままの状態では作動しない。その大きさゆえ、持ち運びはできません。\
	この装置を注文すると、小型のビーコンが送られてきて、起動すると大型のビーコンがあなたのところにテレポートされる。"
	item = /obj/item/sbeacondrop
	cost = 10

/datum/uplink_item/device_tools/powersink
	name = "受電装置"
	desc = "送電網に接続された配線にねじ込んで作動させると、この大型装置が点灯して送電網に過剰な負荷をかけ、局地的な停電を引き起こす。\
	シンクは大きく、従来のほとんどのバッグや箱に収納することができない。\
	注意 パワーネットに十分なエネルギーが含まれている場合、爆発する。"
	item = /obj/item/powersink
	cost = 10
	player_minimum = 35

/datum/uplink_item/device_tools/stimpack
	name = "スティンパック"
	desc = "多くの偉大なヒーローの道具であるスティンパックは注入後約5分間、\
	あらゆる形態のスローダウン（ダメージスローダウンを含む）やスタミナダメージをほとんど受けないようにする。"
	item = /obj/item/reagent_containers/hypospray/medipen/stimulants
	cost = 5
	surplus = 90

/datum/uplink_item/device_tools/medkit
	name = "シンジケート衛生兵キット"
	desc = "茶色と赤の怪しい救急箱です。傷の回復を早めるコンバットインジェクターや、負傷者を素早く確認するためのメディカルナイトビジョンHUDなど、\
	フィールドメディックに必要なものが入っています。"
	item = /obj/item/storage/firstaid/tactical
	cost = 4
	purchasable_from = (UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS)

/datum/uplink_item/device_tools/soap
	name = "シンジケート石鹸"
	desc = "殺人事件の隠蔽やDNA鑑定を防ぐために、血液の汚れを落とすのに使われる不吉な感じのする界面活性剤です。\
	足元に落として人を滑らせることもできる。"
	item = /obj/item/soap/syndie
	cost = 1
	surplus = 50
	illegal_tech = FALSE

/datum/uplink_item/device_tools/surgerybag
	name = "シンジケート手術用ダッフルバッグ"
	desc = "シンジケートの手術用ダッフルバッグは、手術道具一式、手術用ドレープ、シンジケートブランドのMMI、拘束衣、口輪を入れたツールキットです。"
	item = /obj/item/storage/backpack/duffelbag/syndie/surgery
	cost = 3

/datum/uplink_item/device_tools/encryptionkey
	name = "シンジケート暗号鍵"
	desc = "無線機のヘッドセットに差し込むと、すべての局部チャンネルを聞くことができ、\
	同じキーを持つ他のエージェントと暗号化されたシンジケートチャンネルで話すこともできるようになるキーです。"
	item = /obj/item/encryptionkey/syndicate
	cost = 2
	surplus = 75
	purchasable_from = ~UPLINK_INCURSION
	restricted = TRUE

/datum/uplink_item/device_tools/syndietome
	name = "シンジケートの聖書"
	desc = "シンジケートは多額の費用を投じて入手した希少なアーティファクトを使い、\
	ある教団の一見魔法のような書物をリバースエンジニアリングしています。\
	オリジナルに比べれば難解な能力を持っているが、戦場では指を食いちぎられることもあるが、災いも喜びも与えてくれる。"
	item = /obj/item/storage/book/bible/syndicate
	cost = 3

/datum/uplink_item/device_tools/potion
	name = "シンジケートの感覚ポーション"
	item = /obj/item/slimepotion/slime/sentience/nuclear
	desc = "シンジケートの秘密工作員が危険を冒して回収し、その後シンジケートの技術で改造されたポーション。\
	どんな動物でも知覚を持ち、あなたに仕えるようになります。また、通信用の無線機とドアを開けるためのIDカードも内蔵しています。"
	cost = 4
	purchasable_from = (UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS)
	restricted = TRUE

/datum/uplink_item/device_tools/suspiciousphone
	name = "プロトコル CRAB-17 電話番号"
	desc = "プロトコルCRAB-17電話、未知の第三者から借りた電話、それは宇宙市場をクラッシュさせるために使用され、\
	乗組員の損失をあなたの銀行口座に流すことができます。"
	item = /obj/item/suspiciousphone
	restricted = TRUE
	cost = 8

/datum/uplink_item/device_tools/thermal
	name = "熱視力の眼鏡"
	desc = "このゴーグルは、普通のメガネのように見えることもあります。\
	物体から熱や光として放射される赤外線スペクトルの上部をとらえ、壁越しに生物を見ることができる。\
	熱を持った物体、サイバネティック・オーガニズム、\
	人工知能のコアなどは、壁やエアロックなどの低温の物体よりも多くの光を発している。"
	item = /obj/item/clothing/glasses/thermal/syndi
	cost = 3

// Implants
/datum/uplink_item/implants
	category = "インプラント"
	surplus = 50

/datum/uplink_item/implants/adrenal
	name = "副腎インプラント"
	desc = "体内に注入され、後にユーザーの意思で作動するインプラント。\
	化学物質を注入することで、無力化効果を取り除き、より速く走ることができるようになり、軽い治癒効果もある。"
	item = /obj/item/storage/box/syndie_kit/imp_adrenal
	cost = 8
	player_minimum = 20

/datum/uplink_item/implants/antistun
	name = "中枢神経系インプラント"
	desc = "このインプラントは、気絶した後の立ち直りを早くしてくれる。オートサージェリー付き。"
	item = /obj/item/autosurgeon/syndicate/anti_stun
	cost = 12
	surplus = 0
	purchasable_from = UPLINK_NUKE_OPS

/datum/uplink_item/implants/freedom
	name = "自由インプラント"
	desc = "体内に注入され、後にユーザーの意思で作動するインプラント。 \
			手錠のような一般的な拘束からユーザーを解放しようとするものです。"
	item = /obj/item/storage/box/syndie_kit/imp_freedom
	cost = 4

/datum/uplink_item/implants/microbomb
	name = "小型爆弾インプラント"
	desc = "体内に注入され、死亡時に手動または自動で作動するインプラント。 \
			内部にインプラントがあればあるほど、爆発力は高くなります。\
			魔法ではなく、間違いなく本物です。"
	item = /obj/item/storage/box/syndie_kit/imp_microbomb
	cost = 3
	purchasable_from = UPLINK_NUKE_OPS

/datum/uplink_item/implants/macrobomb
	name = "大型爆弾インプラント"
	desc = "体内に注入され、死亡時に手動または自動で作動するインプラント。死亡時に大爆発を起こし、近くのものを全て消し去る。"
	item = /obj/item/storage/box/syndie_kit/imp_macrobomb
	cost = 20
	purchasable_from = UPLINK_NUKE_OPS
	restricted = TRUE

/datum/uplink_item/implants/radio
	name = "シンジケート無線体内インプラント"
	desc = "体内に注入することで、シンジケートの無線機を使用できるようになるインプラント。\
	通常のヘッドセットと同様に使用するが、外部ヘッドセットを正常に使用し、発見されないように無効化することができる。"
	item = /obj/item/storage/box/syndie_kit/imp_radio
	cost = 4
	purchasable_from = ~UPLINK_INCURSION //To prevent traitors from immediately outing the hunters to security.
	restricted = TRUE

/datum/uplink_item/implants/reviver
	name = "蘇生インプラント"
	desc = "意識を失ったときに、蘇生と治癒を試みるインプラントです。オートサージェリー付き。"
	item = /obj/item/autosurgeon/syndicate/reviver
	cost = 7
	surplus = 0
	purchasable_from = UPLINK_NUKE_OPS

/datum/uplink_item/implants/stealthimplant
	name = "隠蔽インプラント"
	desc = "このユニークなインプラントは、あなたが熟練したステルスオペレーターであれば、ほとんど見えなくすることができます。\
	起動すると、カメレオンのダンボール箱の中に隠れますが、誰かがそれにぶつかると、そのことが明らかになります。"
	item = /obj/item/storage/box/syndie_kit/imp_stealth
	cost = 7

/datum/uplink_item/implants/storage
	name = "保管インプラント"
	desc = "体内に注入されたインプラントは、後にユーザーの意志で作動する。\
	通常サイズのものを2つ収納できる小さなポケットを開けることができる。"
	item = /obj/item/storage/box/syndie_kit/imp_storage
	cost = 7

/datum/uplink_item/implants/thermals
	name = "熱視力の目"
	desc = "このサイバネティック目で熱視力を得ることができる。オートサージェリーが無料でついてきます。"
	item = /obj/item/autosurgeon/syndicate/thermal_eyes
	cost = 7
	surplus = 0
	purchasable_from = UPLINK_NUKE_OPS

/datum/uplink_item/implants/uplink
	name = "アップリンクインプラント"
	desc = "体内に注入されたインプラントは、後に使用者の意思で起動する。テレクリスタルを持たず、\
	物理的なテレクリスタルを使って充電する必要がある。手術以外では発見されず、監禁状態からの脱出に優れている。"
	item = /obj/item/storage/box/syndie_kit // the actual uplink implant is generated later on in spawn_item
	cost = UPLINK_IMPLANT_TELECRYSTAL_COST
	// An empty uplink is kinda useless.
	surplus = 0
	restricted = TRUE

/datum/uplink_item/implants/uplink/spawn_item(spawn_path, mob/user, datum/component/uplink/purchaser_uplink)
	var/obj/item/storage/box/syndie_kit/uplink_box = ..()
	uplink_box.name = "アップリンクインプラント"
	new /obj/item/implanter/uplink(uplink_box, purchaser_uplink.uplink_flag)
	return uplink_box


/datum/uplink_item/implants/xray
	name = "X線ビジョンインプラント"
	desc = "このサイバネティック目は、X線透視が可能です。オートサージェリー付き。"
	item = /obj/item/autosurgeon/syndicate/xray_eyes
	cost = 9
	surplus = 0
	purchasable_from = UPLINK_NUKE_OPS


//Race-specific items
/datum/uplink_item/race_restricted
	category = "種制限あり"
	purchasable_from = ~(UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS)
	surplus = 0

/datum/uplink_item/race_restricted/syndilamp
	name = "超高輝度ランタン"
	desc = "蛾はランプが好きだということで、シンジケートの超高輝度ランプのプロトタイプをいち早く公開することにしました。お楽しみに。"
	cost = 2
	item = /obj/item/flashlight/lantern/syndicate
	restricted_species = list(SPECIES_MOTH)

/datum/uplink_item/race_restricted/ethereal_grenade
	name = "エセリアルパーティ手榴弾"
	desc = "シンジケートの科学者たちが、複数のエセリアルの死体を巧妙に詰め込んだ特別なパッケージだ！ \
	起動すると、近くにいる人は誰でも踊ることができる。\
	これを起動すると、エセリアルを除くすべての人が踊り出しますが、エセリアルは気分を害するかもしれません。"
	cost = 4
	item = /obj/item/grenade/discogrenade
	restricted_species = list(SPECIES_ETHEREAL)

/datum/uplink_item/race_restricted/plasmachameleon
	name = "プラズマ人変装キット"
	desc = "変装技術を搭載し、ステーション内のあらゆるものに変装できるアイテムのセットです。予算削減のため、靴には滑り止めがついていない。"
	item = /obj/item/storage/box/syndie_kit/plasmachameleon
	cost = 2
	restricted_species = list(SPECIES_PLASMAMAN)

/datum/uplink_item/race_restricted/tribal_claw
	name = "古トライバル巻物"
	desc = "この巻物はクノイエス一族の廃墟となったトカゲの集落で発見されました。戦闘を有利に進めるための爪と尻尾の使い方を教えてくれる。\
	古代のドラコンを使った言葉を理解できるのはトカゲだけなので、\
	トカゲでない人やトカゲにあげる予定がない人は買わないでください。"
	item = /obj/item/book/granter/martial/tribal_claw
	cost = 14
	surplus = 0
	restricted_species = list(SPECIES_LIZARD)

// Role-specific items
/datum/uplink_item/role_restricted
	category = "役割別制約"
	purchasable_from = ~(UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS)
	surplus = 0

/datum/uplink_item/role_restricted/ancient_jumpsuit
	name = "古代のジャンプスーツ"
	desc = "何の役にも立たないボロボロの古ぼけたジャンプスーツ。身につけると、いたずら心をくすぐられる。"
	item = /obj/item/clothing/under/color/grey/glorf
	cost = 20
	restricted_roles = list(JOB_NAME_ASSISTANT)
	surplus = 1

/datum/uplink_item/role_restricted/oldtoolboxclean
	name = "古代の道具箱"
	desc = "アシスタントを象徴する道具箱のデザインは、中にテレクリスタルを入れることでより強力になります。工具と保温グローブ付き。"
	item = /obj/item/storage/toolbox/mechanical/old/clean
	cost = 2
	restricted_roles = list(JOB_NAME_ASSISTANT)
	surplus = 0

/datum/uplink_item/role_restricted/pie_cannon
	name = "バナナパイ砲"
	desc = "最大20個のパイを収納でき、2秒に1個のパイを自動で作る、特別なピエロのための特別なパイキャノンです。"
	cost = 11
	item = /obj/item/pneumatic_cannon/pie/selfcharge
	restricted_roles = list(JOB_NAME_CLOWN)
	surplus = 0 //No fun unless you're the clown!

/datum/uplink_item/role_restricted/blastcannon
	name = "爆風砲"
	desc = "高度に専門化された武器だが、実は比較的シンプルなものである。\
	超高圧高温に耐える特殊構造パイプにTTV用アタッチメントを装着し、\
	トランスファーバルブを作動させるための機械的トリガーを備えている。\
	つまり、爆弾の爆発力を狭角の爆風波に変えてしまうのです。\
	科学者を志す者にとっては非常に有用である。圧力衝撃波を狭い角度にすることで、\
	一定距離以上の爆発範囲を許容しない物理学の奇妙な癖を回避でき、実際の収量ではなく、\
	移送バルブ爆弾の理論収量を使用することができるようである。"
	item = /obj/item/gun/blastcannon
	cost = 14							//High cost because of the potential for extreme damage in the hands of a skilled scientist.
	restricted_roles = list(JOB_NAME_RESEARCHDIRECTOR, JOB_NAME_SCIENTIST)

/datum/uplink_item/role_restricted/crushmagboots
	name = "重マグブーツ"
	desc = "歩くだけで相手を粉砕する、超強力なマグブーツ。"
	cost = 7
	item = /obj/item/clothing/shoes/magboots/crushing
	restricted_roles = list(JOB_NAME_CHIEFENGINEER, JOB_NAME_STATIONENGINEER, JOB_NAME_ATMOSPHERICTECHNICIAN)

/datum/uplink_item/role_restricted/gorillacubes
	name = "ゴリラキューブ箱"
	desc = "ワッフル社ブランドのゴリラキューブ3個入りの箱。水につけると大きなゴリラになります。"
	item = /obj/item/storage/box/gorillacubes
	cost = 6
	restricted_roles = list(JOB_NAME_GENETICIST, JOB_NAME_CHIEFMEDICALOFFICER)

/datum/uplink_item/role_restricted/rad_laser
	name = "放射性マイクロレーザー"
	desc = "ナノトラセン社製の健康診断機に偽装した放射性マイクロレーザー。\
	使用すると強力な放射線を放出し、短時間のうちに、\
	最も保護されたヒューマノイド以外を無力化させることができる。\
	照射の強さを調節する「インテンシティ」と、効果が発揮されるまでの時間を調節する「ウェーブレングス」の2つの設定があります。"
	item = /obj/item/healthanalyzer/rad_laser
	restricted_roles = list(JOB_NAME_MEDICALDOCTOR, JOB_NAME_CHIEFMEDICALOFFICER, JOB_NAME_ROBOTICIST, JOB_NAME_PARAMEDIC, JOB_NAME_BRIGPHYSICIAN)
	cost = 3

/datum/uplink_item/role_restricted/syndicate_mmi
	name = "シンジケートMMI"
	desc = "サイボーグに搭載されたシンジケートの法律を自動的に適用するMMI。\
	ハッキングされたサイボーグよりも少しステルス性が高いので、既知の味方を加えて支援するのに最適なアイテム。"
	item = /obj/item/mmi/syndie
	restricted_roles = list(JOB_NAME_ROBOTICIST, JOB_NAME_RESEARCHDIRECTOR)
	cost = 2

/datum/uplink_item/role_restricted/upgrade_wand
	name = "アップグレード杖"
	desc = "ナノマシンを搭載した強力な使い捨て杖で、マジシャンがよく使うハイテク機器を約2倍の性能に校正することができます。"
	item = /obj/item/upgradewand
	restricted_roles = list(JOB_NAME_STAGEMAGICIAN)
	cost = 5

/datum/uplink_item/role_restricted/floorpill_bottle
	name = "謎の薬のボトル"
	desc = "数年前に廃止された倉庫R1O-GNに眠っていたものです。捨てようと思っていたのですが、ご興味があるとお聞きしたので。"
	item = /obj/item/storage/pill_bottle/floorpill/full
	restricted_roles = list(JOB_NAME_ASSISTANT)
	cost = 2

/datum/uplink_item/role_restricted/clown_bomb
	name = "クラウン爆弾"
	desc = "クラウン爆弾は、大規模ないたずらができる陽気な装置です。タイマーは60秒から調整可能で、\
	動かないようにスパナで床に固定することができます。この爆弾を注文すると、小型のビーコンが輸送され、\
	起動すると実際の爆弾がそこにテレポートされます。なお、この爆弾は解除することが可能で、クルーによっては解除を試みることもある。"
	item = /obj/item/sbeacondrop/clownbomb
	cost = 10
	restricted_roles = list(JOB_NAME_CLOWN)

/datum/uplink_item/role_restricted/clown_grenade
	name = "C.L.U.W.N.E."
	desc = "C.L.U.W.N.E.は、完全にランダムでホンクマーザーの仲間を1体作ってくるぞ。\
	先に攻撃された場合のみ攻撃し、あなたには忠誠心を持たないので注意が必要だ!"
	item = /obj/item/grenade/spawnergrenade/clown
	cost = 3
	restricted_roles = list(JOB_NAME_CLOWN)


/datum/uplink_item/role_restricted/clown_grenade_broken
	name = "強力C.L.U.W.N.E."
	desc = "C.L.U.W.N.E.は、完全にランダムでホンクマーザーの仲間を1体作ってくるぞ。\
			先に攻撃された場合のみ攻撃し、あなたには忠誠心を持たないので注意が必要だ! \
			この作品には、クラウンのアクションがふんだんに盛り込まれています！使用には注意が必要です。"
	item = /obj/item/grenade/spawnergrenade/clown_broken
	cost = 5
	restricted_roles = list(JOB_NAME_CLOWN)


/datum/uplink_item/role_restricted/spider_injector
	name = "オーストラリアからスライム変異体"
	desc = "オーストラリクス・セクターからの旅は 大変だったが... \
	巨大なクモから特別な 抽出液を手に入れることができた。\
	このインジェクターをゴールド・スライム・コアにセットして向こうの惑星で見つけたのと同じ種類のクモを作るんだ。\
	このインジェクターを金のスライムコアにつければ、向こうの惑星にいるのと同じ種類のクモを何匹か作ることができる。"
	item = /obj/item/reagent_containers/syringe/spider_extract
	cost = 10
	restricted_roles = list(JOB_NAME_RESEARCHDIRECTOR, JOB_NAME_SCIENTIST, JOB_NAME_ROBOTICIST)

/datum/uplink_item/role_restricted/clowncar
	name = "クラウン車"
	desc = "クラウン車は、クラウンの究極の移動手段です。バイクホーンを挿して乗り込むだけで、人生で一番楽しいドライブができるぞ。\
	あなたは、あなたが遭遇したすべての人々を突っ込んで、あなたの車に詰め込み、それらを誘拐し、誰かが彼らを救うか、彼らが何とか這い出てくるまで、\
	車内に閉じ込めることができます。バネ式のシートは非常に敏感なので、壁や自動販売機に突っ込まないように注意してください。また、\
	ルーブディフェンス機構が搭載されているので、怒った警備員からあなたを守ります。プレミアム機能が電磁カードで使える!"
	item = /obj/vehicle/sealed/car/clowncar
	cost = 20
	restricted_roles = list(JOB_NAME_CLOWN)
	purchasable_from = ~UPLINK_INCURSION

/datum/uplink_item/role_restricted/taeclowndo_shoes
	name = "テクラウンドーの靴"
	desc = "最もエリートな道化師のための一足の靴。クラウンの秘伝の武術を習得することができる。"
	cost = 12
	item = /obj/item/clothing/shoes/clown_shoes/taeclowndo
	restricted_roles = list(JOB_NAME_CLOWN)

/datum/uplink_item/role_restricted/superior_honkrender
	name = "全能のホンクレンダ"
	desc = "古代の洞窟から回収された古代の遺物。ダークカーニバルへの道を開く。"
	item = /obj/item/veilrender/honkrender
	cost = 8
	restricted = TRUE
	restricted_roles = list(JOB_NAME_CLOWN, JOB_NAME_CHAPLAIN)

/datum/uplink_item/role_restricted/superior_honkrender
	name = "大全能のホンクレンダ"
	desc = "古代の遺物が回収された-。TRANSMISSION OFFLINE"
	item = /obj/item/veilrender/honkrender/honkhulkrender
	cost = 20
	restricted = TRUE
	restricted_roles = list(JOB_NAME_CLOWN, JOB_NAME_CHAPLAIN)

/datum/uplink_item/role_restricted/concealed_weapon_bay
	name = "メカの隠れ武器改造"
	desc = "非戦闘用メカの改造で、戦闘用メカの装備品を1つ装備できるようになる。\
			装備した武器も見えなくなる。1機につき1つまでしか装着できない。"
	item = /obj/item/mecha_parts/concealed_weapon_bay
	cost = 3
	restricted_roles = list(JOB_NAME_ROBOTICIST, JOB_NAME_RESEARCHDIRECTOR)

/datum/uplink_item/role_restricted/haunted_magic_eightball
	name = "呪術8ボール"
	desc = "ほとんどのマジックエイトボールは、中にサイコロが入った玩具です。\
	見た目は無害なおもちゃと同じですが、このオカルト装置は霊界に答えを探しに行くのです。\
	ただし、霊は気まぐれであったり、無作法であったりするので注意が必要です。\
	使い方は、質問したいことを声に出して言い、振り始めるだけです。"
	item = /obj/item/toy/eightball/haunted
	cost = 2
	restricted_roles = list(JOB_NAME_CURATOR)
	limited_stock = 1 //please don't spam deadchat

/datum/uplink_item/role_restricted/voodoo
	name = "ブードゥー人形"
	desc = "空洞に小物を収納することができる魔法のブードゥー人形。\
	小物を収納すると、収納した小物に接触した他人の行動を操作することができる。"
	item = /obj/item/voodoo
	cost = 12
	restricted_roles = list(JOB_NAME_CURATOR, JOB_NAME_STAGEMAGICIAN)

/datum/uplink_item/role_restricted/prison_cube
	name = "魔法禁固立方体"
	desc = "火山惑星から回収された非常に奇妙なアーティファクトは、人々を閉じ込めておくには便利だが、その消息を知られないようにするにはあまり役立たない。"
	item = /obj/item/prisoncube
	cost = 6
	restricted_roles = list(JOB_NAME_CURATOR)

/datum/uplink_item/role_restricted/his_grace
	name = "ご大王殿下道具箱"
	desc = "グレイ・タイドに支配されたステーションから回収された、非常に危険な兵器。一度起動すると、殿下は血を渇望し、その渇望を満たすために殺しに使わなければならない。 \
	ご大王殿下道具箱は、使用者に緩やかな再生と完全なスタン免疫を与えるが、注意が必要で、空腹になりすぎると落とすことができなくなり、最終的には食べさせないと死んでしまう。 \
	しかし、長い間放っておくと、殿下はまた眠りについてしまいます。 \
	大王殿下道具箱を起動するには、大王殿下のラッチを外すだけです。"
	item = /obj/item/his_grace
	cost = 20
	restricted_roles = list(JOB_NAME_CHAPLAIN)
	murderbone_type = TRUE
	surplus = 0

/datum/uplink_item/role_restricted/cultconstructkit
	name = "カルト使い魔キット"
	desc = "ナルシエ教団の廃墟から回収されたコンストラクトシェル2個と空のソウルストーンの隠し場所から発見された。\
	これらはオカルト汚染を防ぐために浄化され、使い捨てのミニオンの供給源として利用できるようベルトに入れられた。\
	コンストラクトシェルは2つのビーコンに梱包され、迅速かつ持ち運びができるようになった。"
	item = /obj/item/storage/box/syndie_kit/cultconstructkit
	cost = 20
	restricted_roles = list(JOB_NAME_CHAPLAIN)

/datum/uplink_item/role_restricted/spanish_flu
	name = "スペイン風邪の瓶"
	desc = "異端者を地獄の業火で焼き尽くす、怒れる魂が宿る呪われた血の瓶。\
	少なくとも、ラベルにはそう書かれている。"
	item = /obj/item/reagent_containers/glass/bottle/fluspanish
	cost = 14
	restricted_roles = list(JOB_NAME_CHAPLAIN, JOB_NAME_VIROLOGIST)

/datum/uplink_item/role_restricted/retrovirus
	name = "レトロウイルス科の瓶"
	desc = "伝染性のDNAウイルスが入ったボトルで、宿主のDNAを手動で並べ替える。"
	item = /obj/item/reagent_containers/glass/bottle/retrovirus
	cost = 14
	restricted_roles = list(JOB_NAME_VIROLOGIST, JOB_NAME_GENETICIST)

/datum/uplink_item/role_restricted/random_disease
	name = "実験的疾患"
	desc = "ランダムな病気。もしかしたら、レベル9の症状が出るラッキーなことがあるかもしれません。"
	item = /obj/item/reagent_containers/glass/bottle/random_virus
	cost = 5
	restricted_roles = list(JOB_NAME_VIROLOGIST)
	surplus = 20

/datum/uplink_item/role_restricted/anxiety
	name = "不安神経症の瓶"
	desc = "純粋な伝染病の瓶。"
	item = /obj/item/reagent_containers/glass/bottle/anxiety
	cost = 4
	restricted_roles = list(JOB_NAME_VIROLOGIST)

/datum/uplink_item/role_restricted/explosive_hot_potato
	name = "爆裂ホットポテト"
	desc = "爆薬を仕込んだポテト。起動すると特殊な機構が働き、落とせなくなる。\
	自分が持っている時は他の人を攻撃することで、代わりにその人にくっつくしかない。"
	item = /obj/item/hot_potato/syndicate
	cost = 3
	surplus = 0
	restricted_roles = list(JOB_NAME_COOK, JOB_NAME_BOTANIST, JOB_NAME_CLOWN, JOB_NAME_MIME)

/datum/uplink_item/role_restricted/echainsaw
	name = "エナジーチェーンソー"
	desc = "金属の代わりにプラズマを利用したエネルギーブレードを使用し、\
	黒と赤の光沢のある仕上げが施された、\
	非常に殺傷力の高い改造チェーンソーです。非常に高い効率で物質を切り裂くが、重く、大きく、音も大きい。"
	item = /obj/item/chainsaw/energy
	cost = 10
	player_minimum = 25
	restricted_roles = list(JOB_NAME_BOTANIST, JOB_NAME_COOK, JOB_NAME_BARTENDER)

/datum/uplink_item/role_restricted/holocarp
	name = "聖魚寄生虫"
	desc = "鯉の神に敬意を表して儀式的に作られたフィッシュスティックで、ホログラムの鯉を縛って、宿主の下僕や守護神として働かせることができる。"
	item = /obj/item/guardiancreator/carp
	cost = 18
	surplus = 5
	purchasable_from = ~(UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS)
	player_minimum = 25
	restricted = TRUE
	restricted_roles = list(JOB_NAME_COOK, JOB_NAME_CHAPLAIN)

/datum/uplink_item/role_restricted/ez_clean_bundle
	name = "「EZ Clean」 手榴弾バンドル"
	desc = "ワッフル社のトレードマークである「クリーナーグレネード」が3つ入った箱。クリーナーとして機能し、近くにいる人に酸のダメージを与える。\
	酸は炭素系の生物にしか効かない"
	item = /obj/item/storage/box/syndie_kit/ez_clean
	cost = 6
	surplus = 20
	restricted_roles = list(JOB_NAME_JANITOR)

/datum/uplink_item/role_restricted/mimery
	name = "上級者向けマイムガイド"
	desc = "パントマイムの技術をさらに磨くための古典的な2部構成です。\
	このシリーズを学ぶと、3x1の見えない壁を作ったり、指から弾丸を撃ったりできるようになります。もちろんパントマイマーにしか使えないが"
	cost = 11
	item = /obj/item/storage/box/syndie_kit/mimery
	restricted_roles = list(JOB_NAME_MIME)
	surplus = 0

/datum/uplink_item/role_restricted/mimesabrekit
	name = "バゲットの刃"
	desc = "バゲット型のシースには、非常にステルス性の高いブレードが内蔵されています。"
	cost = 	12
	item = /obj/item/storage/box/syndie_kit/mimesabrekit
	restricted_roles = list(JOB_NAME_MIME)
	surplus = 5

/datum/uplink_item/role_restricted/pressure_mod
	name = "KA圧力モッド"
	desc = "キネティックアクセラレーターのダメージが室内で大幅に増加する改造キットです。改造能力35%占有"
	item = /obj/item/borg/upgrade/modkit/indoors
	cost = 5 //you need two for full damage, so total of 10 for maximum damage
	limited_stock = 2 //you can't use more than two!
	restricted_roles = list(JOB_NAME_SHAFTMINER)

/datum/uplink_item/role_restricted/esaw
	name = "エネルギー鋸"
	desc = "必殺のエネルギーソー。光沢のある黒仕上げ。"
	cost = 5
	item = /obj/item/melee/transforming/energy/sword/esaw
	restricted_roles = list("Medical Doctor", "Chief Medical Officer", "Paramedic", "Brig Physician")

/datum/uplink_item/role_restricted/esaw_arm
	name = "エネルギー鋸腕インプラント"
	desc = "腕の中に必殺のエネルギーソーを付与するインプラント。シンジケートのオートサージェリーが付属しており、すぐに自分で装着することができる。"
	cost = 8
	item = /obj/item/autosurgeon/syndicate/esaw_arm
	restricted_roles = list(JOB_NAME_MEDICALDOCTOR, JOB_NAME_CHIEFMEDICALOFFICER, JOB_NAME_PARAMEDIC, JOB_NAME_BRIGPHYSICIAN)

/datum/uplink_item/role_restricted/magillitis_serum
	name = "ゴリラの力注入器"
	desc = "人間の筋肉を急速に成長させる実験的な血清が入った、使い切りの自動注射器です。副作用として、多毛、暴発、バナナへの執着が続くことがある。"
	item = /obj/item/reagent_containers/hypospray/medipen/magillitis
	cost = 15
	restricted_roles = list(JOB_NAME_GENETICIST, JOB_NAME_CHIEFMEDICALOFFICER)

/datum/uplink_item/role_restricted/modified_syringe_gun
	name = "変形シリンジガン"
	desc = "通常の注射器の代わりにDNAインジェクターを発射する注射器ガン。"
	item = /obj/item/gun/syringe/dna
	cost = 14
	restricted_roles = list(JOB_NAME_GENETICIST, JOB_NAME_CHIEFMEDICALOFFICER)

/datum/uplink_item/role_restricted/chemical_gun
	name = "試薬ダートガン"
	desc = "入力された試薬を使って、自らケミカルダーツを合成することができるシリンジガンを大幅に改造したもの。100uの試薬が収納可能。"
	item = /obj/item/gun/chem
	cost = 12
	restricted_roles = list(JOB_NAME_CHEMIST, JOB_NAME_CHIEFMEDICALOFFICER)

/datum/uplink_item/role_restricted/reverse_bear_trap
	name = "リバースベアトラップ"
	desc = "頭部に装着する（または強制的に装着させる）独創的な処刑装置。\
	ベアトラップに取り付けられた1分間のキッチンタイマーが作動する。タイマーが切れると、罠の顎が激しく開き、\
	装着している人の顎を真っ二つにして瞬時に殺す。武装させるには、\
	相手がヘッドギアを装着していない状態で攻撃し、3秒以上中断した後、強制的に頭に装着させる。"
	cost = 4
	item = /obj/item/reverse_bear_trap
	restricted_roles = list(JOB_NAME_CLOWN)

/datum/uplink_item/role_restricted/reverse_revolver
	name = "リバース回転式拳銃"
	desc = "常に使用者に向けて発射される回転式拳銃。\
	誤って銃を落としてしまうと、貪欲な企業豚が自分の脳みそを壁一面に吹き飛ばすのを見ることができる。\
	回転式拳銃は実在するんだ 不器用な人とピエロ以外は普通に撃てるよ。"
	cost = 13
	item = /obj/item/storage/box/hug/reverse_revolver
	restricted_roles = list(JOB_NAME_CLOWN)

/datum/uplink_item/role_restricted/laser_arm
	name = "レーザー腕インプラント"
	desc = "腕の中に充電式のレーザーガンを付与するインプラント。\
	EMPに弱い。シンジケートのオートサージェリーが付属しており、すぐに自分で装着することができる。"
	cost = 12
	item = /obj/item/autosurgeon/syndicate/laser_arm
	restricted_roles = list(JOB_NAME_ROBOTICIST, JOB_NAME_RESEARCHDIRECTOR)


// Pointless
/datum/uplink_item/badass
	category = "(詰まらない)壮言大語"
	surplus = 0


/datum/uplink_item/badass/costumes
	surplus = 0
	cost = 4
	cant_discount = TRUE
	purchasable_from = (UPLINK_NUKE_OPS | UPLINK_CLOWN_OPS)

/datum/uplink_item/badass/costumes/obvious_chameleon
	name = "壊れた変装キット"
	desc = "変装技術を搭載し、ステーション内のあらゆるものに変装できるアイテムのセットです。\
	このキットは品質管理に合格していませんのでご注意ください。"
	item = /obj/item/storage/box/syndie_kit/chameleon/broken
	cost = 2
	purchasable_from = ALL

/datum/uplink_item/badass/costumes/centcom_official
	name = "セントコム公式コスチューム"
	desc = "核ディスクと兵器システムを点検するようクルーに要求し、断られたらフルオートライフルを取り出し、\
	船長を銃殺する。無線機のヘッドセットには暗号キーは含まれません。銃は付属していません。"
	item = /obj/item/storage/box/syndie_kit/centcom_costume

/datum/uplink_item/badass/costumes/clown
	name = "クラウンのコスチューム"
	desc = "完全自動小銃を持ったピエロほど怖いものはない。"
	item = /obj/item/storage/backpack/duffelbag/clown/syndie

/datum/uplink_item/badass/balloon
	name = "シンジケートバルーン"
	desc = "あなたが「THE BOSS」であることを示すために。シンジケートのロゴが入った、役に立たない赤い風船。"
	item = /obj/item/toy/syndicateballoon
	cost = 20
	cant_discount = TRUE
	illegal_tech = FALSE
	surplus = 0

/datum/uplink_item/badass/syndiebeer
	name = "シンジケートビール"
	desc = "毒素を排出するために作られたシンジケートブランドの「ビール」。警告 1本以上飲んではいけません"
	item = /obj/item/reagent_containers/food/drinks/syndicatebeer
	cost = 4
	illegal_tech = FALSE

/datum/uplink_item/badass/syndiecash
	name = "懐紙筒"
	desc = "5000スペースクレジットの入った安全な書類鞄。職員への賄賂や、有利な価格での商品・サービスの購入に役立つ。\
	また、この書類鞄を持つと少し重く感じる。クライアントに説得力を与えるために、もう少しパンチを効かせるように製造されている。"
	item = /obj/item/storage/secure/briefcase/syndie
	cost = 1
	restricted = TRUE
	illegal_tech = FALSE

/datum/uplink_item/badass/syndiecards
	name = "シンジケートトランプ"
	desc = "単分子エッジと金属補強により、通常のトランプより若干頑丈に作られた宇宙仕様の特殊トランプ。\
	これでカードゲームをしたり、テレホンカードを残したりすることもできます。"
	item = /obj/item/toy/cards/deck/syndicate
	cost = 1
	surplus = 40
	illegal_tech = FALSE

/datum/uplink_item/badass/syndiecigs
	name = "シンジケート紙巻タバコ"
	desc = "強い味わい、濃厚な煙、オムニジンが溶け込んでいる。"
	item = /obj/item/storage/fancy/cigarettes/cigpack_syndicate
	cost = 2
	illegal_tech = FALSE

/datum/uplink_item/badass/toy_box
	name = "株式会社ドンクの箱おもちゃ"
	desc = "ドンコのおもちゃが詰まった、親からすごいプレゼントが欲しい子のためのスペシャルパッケージボックスです。\
	箱の中のおもちゃは、ナノトラセンの安全保証によって承認された、完全に安全で有害ではないものです。箱が赤い理由は聞かないでね。"
	item = /obj/item/storage/box/syndie_kit/toy_box
	cost = 2
	surplus = 0

/datum/uplink_item/implants/deathrattle
	name = "遺告のインプラント"
	desc = "チームに注入すべきインプラントのコレクション(と再利用可能なインプランター1個)。\
	チームの誰かが死ぬと、他のインプラント保有者全員に、チームメイトの名前と死んだ場所を知らせるメンタルメッセージが送られる。\
	一般的なインプラントとは異なり、生物・機械問わず、あらゆる生物に移植できるよう設計されている。"
	item = /obj/item/storage/box/syndie_kit/imp_deathrattle
	cost = 4
	surplus = 0
	purchasable_from = UPLINK_NUKE_OPS

/datum/uplink_item/device_tools/antag_lasso
	name = "マインドスレイブ投げ縄"
	desc = "最新鋭のテイム装置。　この装置を使って、ほとんどの動物を縄で縛ったり解いたりすることで手なずけることができます。\
	手なずけられた動物には、騎乗して命令することができます。"
	item = /obj/item/mob_lasso/antag
	cost = 3
	surplus = 0
