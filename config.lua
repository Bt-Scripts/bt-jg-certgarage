Config = {}

Config.Certs = {

    ['police_hwy'] = {
        label       = 'Highway Certification',
        description = 'Highway certification garage',
        givers = {
            ['police'] = 6,
        },
        managers = {
            ['police'] = 6, 
        },
    }

}


Config.GarageRequirements = {

     ['Police_hwy'] = {
         job      = 'police',
         cert     = 'police_hwy',
         minGrade = 5,
     }
}
