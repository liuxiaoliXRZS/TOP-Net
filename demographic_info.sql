with weight as (
	select icustay_id
	, weight 
	, ROW_NUMBER() OVER (PARTITION BY icustay_id order by starttime) as rn 
	from `physionet-data.mimiciii_derived.weightdurations` wt
	where weight is not null
)

, basic_info_0 as (
	select icud.subject_id
	, icud.hadm_id
	, icud.icustay_id
	, icud.gender
	, icud.admission_age as age
	, ad.admission_type
	, ie.first_careunit
	, wt.weight
	, coalesce(ht.height, ht.height_chart, ht.height_echo)/100 as height
	from `physionet-data.mimiciii_derived.icustay_detail` icud
	inner join `physionet-data.mimiciii_clinical.icustays` ie 
	on icud.icustay_id = ie.icustay_id
	left join weight wt 
	on icud.icustay_id = wt.icustay_id
	and wt.rn = 1
	left join `physionet-data.mimiciii_clinical.admissions` ad 
	on icud.hadm_id = ad.hadm_id
	left join `physionet-data.mimiciii_derived.heightfirstday` ht
	on icud.icustay_id = ht.icustay_id
	where icud.first_icu_stay = true
	and icud.first_hosp_stay = true
)

, basic_info as (
	select subject_id
	, hadm_id
	, icustay_id
	, gender
	, age
	, admission_type
	, first_careunit
	, weight/(height * height) as bmi -- 体质指数（BMI）=体重（kg）÷身高^2（m）
	from basic_info_0
)

, diag_info_0 as (
	select subject_id
	, hadm_id
	, case when substring(icd9_code,1,2) in ('39', '40', '41', '42', '43', '44', '45') then 1
	when substring(icd9_code,1,4) in ('2535', '3572', '5881', '7751', 'V771', 'V180') then 1
	when substring(icd9_code,1,5) in ( '64800', '64801', '64802', '64803', '64804', 'V1221', '99791') then 1
	else 0 end as card_disease_flag
	from `physionet-data.mimiciii_clinical.diagnoses_icd`
)

, diag_info as (
	select subject_id, hadm_id, max(card_disease_flag) as card_disease_flag
	from diag_info_0
	group by subject_id, hadm_id
)

select bi.subject_id
, bi.gender
, round(bi.age, 2) as age
, bi.admission_type
, bi.first_careunit
, bi.bmi
, di.card_disease_flag
from basic_info bi
left join diag_info di
on bi.subject_id = di.subject_id
and bi.hadm_id = di.hadm_id
where bi.age >= 18