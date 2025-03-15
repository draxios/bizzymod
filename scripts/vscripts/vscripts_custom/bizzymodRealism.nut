 //-----------------------------------------------------
 Msg("Activating bizzymod Realism\n");
 
 
 DirectorOptions <-
 {
 	ActiveChallenge = 1
 
 	cm_AllowPillConversion = 0
 
 	ZombieGhostDelayMin = 15
 	ZombieGhostDelayMax = 16
 
 	weaponsToRemove =
 	{
 		weapon_first_aid_kit = 0
 	}
 
 	function AllowWeaponSpawn( classname )
 	{
 		if ( classname in weaponsToRemove )
 		{
 			return false;
 		}
 		return true;
 	}		
 
 	DefaultItems =
 	[
 		"weapon_pistol",
 	]
 
 	function GetDefaultItem( idx )
 	{
 		if ( idx < DefaultItems.len() )
 		{
 			return DefaultItems[idx];
 		}
 		return 0;
 	}	
 }