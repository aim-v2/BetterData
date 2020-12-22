return {
	ExternalDatabase = {
		Token = "https://teste-deac1-default-rtdb.firebaseio.com/", -- Do not put .json in the end.
		Retries = 5
	},

	Options = {
		SaveInStudio = false,
		AutoSave = false,
		
		ExternalDatabase = false,
	},

	Retries = 10,
	INTERVAL = 70 --Has to be greater than 60
}
