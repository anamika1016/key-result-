require "csv"

class InsertEmployeeTrainingMasterData < ActiveRecord::Migration[8.0]
  class TrainingOffice < ActiveRecord::Base
    self.table_name = "employee_training_offices"
  end

  class TrainingProject < ActiveRecord::Base
    self.table_name = "employee_training_projects"
  end

  PROJECT_NAMES = [
    "OPIL",
    "Bajaj Finserve MH",
    "Inditex-MP",
    "Inditex-OR",
    "Where there is well",
    "NAFED FPO",
    "NCDC Bihar",
    "SFAC FPO",
    "UNDP-Mandla",
    "Ashraya Hastha Trust",
    "Axix Bank Foundation",
    "Corteva",
    "ILO",
    "JRD Tata Trust",
    "NABARD FPO CG",
    "NABARD FPO GJ",
    "NABARD FPO MH",
    "NABARD FPO UP",
    "NABARD FPO MP",
    "NABARD FPO MP-New",
    "NABARD-WDF-Sidhi",
    "NCDC Jharkhand",
    "NABARD FPO Bihar",
    "NABARD FPO JH-New",
    "NABARD FPO JH",
    "SBI Foundation",
    "Aranya-ASA",
    "Vasundhara"
  ].freeze

  TRAINING_OFFICES = <<~CSV
    office_type,office_name,fpo_name
    FCO-Ratlam,TO-Rawti,Shivgarh Mahila Farmer Producer Company Limited
    FCO-Ratlam,TO-Rawti,Raoti Mahila Farmer Producer Company Limited
    FCO-Ratlam,TO-Rawti,Bajna Mahila Farmer Producer Company Limited
    FCO-Ratlam,TO-Ratlam,Ratlam Adiwasi Kisan Producer Company Limited
    FCO-Ratlam,TO-Neemuch,Neemuch Sfac Women Farmer Producer Company Limited
    FCO-Ratlam,TO-Neemuch,Jawad Sfac Women Farmer Producer Company Limited
    FCO-Ratlam,TO-Khachrod,Khachrod Farmer Producer Company Limited
    FCO- Betul,TO- Betul,Ma Machna Crop Producer Company Limited
    FCO- Betul,TO- Betul,Betul Sfac Women Farmer Producer Company Limited
    FCO- Betul,TO- Betul,Athner Sfac Women Farmer Producer Company Limited
    FCO- Betul,TO- Kurai(Seoni),Pench Valley Women Farmer Producer Company Limited
    FCO- Betul,TO- Kurai(Seoni),Mogli Agroventure Women Farmer Producer Company Limited
    FCO- Ambikapur,TO-Sitapur,Sarguja Mahila Farmer Producer Company Limited
    FCO- Ambikapur,TO- Bastar,Nawa Bastar Kisan Producer Company Limited
    FCO- Ambikapur,TO- Bastar,Bakawand Kisan Producer Company Limited
    FCO- Ambikapur,TO- Bastar,Mahamaya Mahila Kisan Producer Company Limited
    FCO- Jamtara,,Asura Utkarsh Krishi Bagwani Swawalambi Sahkari Samiti Limited
    FCO- Jamtara,,Bara Jhinkpani Utkarsh Krishi Bagwani Swawalambi Sahkari Samiti Limited
    FCO- Jamtara,,Boikera Panchayat Krishi Bagwani Swawalambi Sahkari Samiti Limited
    FCO- Jamtara,,Manjhiaon Farmer Producer Company Limited
    FCO- Jamtara,,Meral Pragatisheel Farmer Producer Company Limited
    FCO- Jamtara,,Ramghar Adarsh Kisan Producer Company Ltd
    FCO- Jamtara,,Panki Sukrit Farmer Producer Company Limited
    FCO- Jamtara,,Betla Kisan Producer Company Limited
    FCO- Jamtara,TO-Jharmundi,Jarmundi Utkarsh Krishi Bagwani Swawalambi Sahkari Samiti Limited
    FCO- Jamtara,TO-Jharmundi,Gopikandar Utkarsh Krishi Bagwani Swawalambi Sahkari Samiti Limited
    FCO- Jamtara,TO- Sarhait,Sarath Mahila Producer Company Ltd
    FCO-Pakur,FPO Barhait,Barhait Farmer Producer Company Ltd
    FCO-Pakur,FPO Barhait,Pathna Krishi Baghbani Kisan Producer Company Limited
    FCO-Pakur,TO-Hiranpur,Pakur Women Farmers Producer Company Limited
    FCO - Barauni,TO-Barauni,Kiul Farmers Producer Company limited
    FCO - Barauni,TO-Barauni,Ulai Jhajha Mahila Farmers Producer Company Limited
    FCO - Barauni,TO-Barauni,KRISHI KALYANPUR PRODUCER COMPANY LIMITED
    FCO - Barauni,TO-Barauni,"Rani Krishi Bagwani Swawlambi Sahkari Samiti Ltd, Bacchwara"
    FCO - Barauni,TO-Barauni,"Barauni Krishi Bagwani Swawlambi Sahkari Samiti Ltd., Barauni"
    FCO - Barauni,TO-Barauni,Mansurchak Krishi Bagwani Swawlambi Sahkari Samiti Ltd.
    FCO - Barauni,TO-Barauni,Matihani Krishi Bagwani Swawlambi Sahkari Samiti ltd.
    FCO - Barauni,TO-Barauni,Khanpur Krishi Bagwani Swavlambi Sahkari Samiti Ltd.
    FCO - Barauni,TO-Barauni,Rosera Krishi Bagwani Swavlambi Sahakari Samiti Ltd.
    FCO - Barauni,TO-Barauni,Aadarsh Jaiv Vikas Krishi Bagwani Swavlambi Sahkari Samiti Ltd.
    FCO- Jobat,TO-Kukshi,Kukshi Tribal Farmer Producer Company Limited
    FCO- Jobat,TO-Dahi,Bhuvada Baba Mahila Farmers Producer Company Limited
    FCO- Jobat,TO-Nanpur,Nanpur Adivasi Kisan Producer Company Limited
    FCO- Jobat,TO-Jobat,Alirajpur Tribal Producer Company Limited
    FCO- Jobat,,Udaigarh Aadiwasi Kisan Producer Company Limited
    FCO- Shahdol,CTO-Umaria,Bandhavgarh Krishak Producer Company Limited
    FCO- Shahdol,CTO-Jaisinghnagar,Jaisinghnagar Farmer Producer Company Limited
    FCO- Shahdol,CTO-Jaisinghnagar,Somnadi Farmer Producer Company Limited
    FCO- Shahdol,,Birsinghpur Farmer Producer Company Limited
    FCO- Shahdol,,Burhar Kisan Producer Company Limited
    FCO- Shahdol,TO-Sidhi,Gopadbanas Kisan Producer Company Limited
    FCO-Agra,,Fatehpur Sikri Fed Women Farmer Producer Company Limited
    FCO-Agra,,Fed Saiyan Women Farmer Producer Company Limited
    FCO-Agra,,Kheragarh Fed Women Farmer Producer Company Limited
    FCO-Agra,,Jagner Fed Women Farmer Producer Company Limited
    FCO-Agra,TO-Naraini,Manikpur Fed Women Farmer Producer Company Limited
    FCO-Agra,TO-Naraini,Jaspura Unnat Kisan Producer Company Limited
    FCO-Agra,TO-Naraini,Kalinjar Naraini Farmer Producer Company Limited
    FCO-Bhabra,FCO-Bhabra,Bhabra Tribal Producer Company Limited
    FCO-Bhabra,TO-Sondhwa,Dungar Tribal Producer Company Limited
    FCO-Bhabra,TO-Pavi Jetpur,Orsang Kisan Producer Company Limited
    FCO-Bhawanipatna (Kalahandi),TO-Kesinga,Budhadangar Jeebika Farmers Producer Company Limited
    FCO-Bhawanipatna (Kalahandi),TO-Kesinga,Bastrani Women Farmers Producer Company Limited
    FCO-Ranapur,TO-Kakanwani,Kakanwani Mahila Kisan Producer Company Limited
    FCO-Ranapur,TO-Ranapur,Ranapur Tribal Mahila Farmer Producer Company Limited
    FCO-Ranapur,TO- Petlawad,Petlawad Tribal Farmer Producer Company Limited
    FCO-Ranapur,Sub-TO-Pitol(Sub TO of Ranapur),Pitol Tribal Farmer Producer Company Limited
    FCO-Ranapur,Sub-TO-Pitol(Sub TO of Ranapur),Kundanpur Adiwasi Kisan Producer Company Limited
    FCO-Ranapur,TO- Para,Para Adiwasi Kisan Producer Company Limited
    FCO-Ranapur,TO-Meghnagar,Anaas Adivasi Kisan Farmer Producer Company Ltd
    FCO-Kotma,TO-Kotma,Kapildhara Kisan Producer Company Limited
    FCO-Kotma,TO-Jaithari,Jaithari Farmer Producer Company Limited
    FCO-Kotma,TO-Pushparajgarh,Johila Tribal Farmer Producer Company Limited
    FCO-Kotma,,Ambada Mahila Kisan Producer Company Limited
    FCO-Morena,,Kailaras Fed Women Farmer Producer Company Limited
    FCO-Morena,,Joura Fed Women Farmer Producer Company Limited
    FCO-Morena,,Pahadgarh Fed Women Farmer Producer Company Limited
    FCO-Morena,,Karera Sfac Women Farmer Producer Company Limited
    FCO-Morena,,Pichhore Sfac Women Farmer Producer Company Limited
    FCO - Mandala,TO-Bichaiya,Anjaniya Tribal Farmers Producer Company Limited
    FCO - Mandala,TO-Mandala,Mandla Tribal Farmer'S Producer Company Limited
    FCO - Mandala,TO-Mandala,Maheshmati Tribal Farmer' S Producer Company Limited
    FCO - Mandala,TO-Mehandwani,Dindori Kisan Producer Company Limited
    FCO - Mandala,TO-Shahpura,Vindhvashni Shahpura Kisan Producer Company Limited
    FCO- Rajpur,TO-Ojhar,Nimad Farmers Producer Company Limited
    FCO- Rajpur,TO-Rajpur,Barwani Farmer Producer Company Limited
    FCO- Rajpur,TO-Rajpur,Palsud Mahila Kisan Producer Company Limited
    FCO- Rajpur,TO-Pati,Pati Mahila Farmer Producer Company Limited
    FCO- Rajpur,TO-Sendhwa,Sendhwa Aadiwasi Mahila Kisan Producer Company Limited
    FCO- Rajpur,TO-Atarikhejda,Atarikhejda Farmer Producer Company Limited
  CSV

  def up
    PROJECT_NAMES.each do |name|
      project = TrainingProject.find_or_initialize_by(name: name)
      project.active = true
      project.save!
    end

    CSV.parse(TRAINING_OFFICES, headers: true).each do |row|
      office_type = row["office_type"].to_s.strip
      office_name = row["office_name"].to_s.strip.presence
      fpo_name = row["fpo_name"].to_s.strip
      next if office_type.blank? || fpo_name.blank?

      office = TrainingOffice.find_or_initialize_by(
        office_type: office_type,
        office_name: office_name,
        fpo_name: fpo_name
      )
      office.active = true
      office.save!
    end
  end

  def down
    TrainingProject.where(name: PROJECT_NAMES).delete_all

    CSV.parse(TRAINING_OFFICES, headers: true).each do |row|
      TrainingOffice.where(
        office_type: row["office_type"].to_s.strip,
        office_name: row["office_name"].to_s.strip.presence,
        fpo_name: row["fpo_name"].to_s.strip
      ).delete_all
    end
  end
end
