/*-------------------------------------*/
/*------------ QUESTION 1 -------------*/
/*-------------------------------------*/

/* ---- Création des librairies ----*/

options validvarname=any; /*Evite les erreurs de conversions dans les noms de variables*/

/* Création des librairies */
LIBNAME XL_2017 XLSX '/home/u62478841/TD6/Hospi_2017.xlsx';
LIBNAME XL_2018 XLSX '/home/u62478841/TD6/Hospi_2018.xlsx';
LIBNAME XL_2019 XLSX '/home/u62478841/TD6/Hospi_2019.xlsx';

/*Supprimer les librairies*/
/*libname XL_2017 clear;
libname XL_2018 clear;
libname XL_2019 clear;*/

/*-------------------------------------*/
/*------------ QUESTION 2 -------------*/
/*-------------------------------------*/

/* ---- Analyse ----*/

/* Chaque fichier est composé de 4 feuilles :
	- Indacteur : Décrit les différents indicateurs du dataset
	- Etablissement : Catégorie de l'établissement et classification des tailles de services
	- Lits et places : variables concernant le nb de lits par services 
	- Activités globales : Autres variables 
*/

/* ---- Problèmes de qualité ----*/
	/*Détection de doublons*/
	
proc sort data=XL_2017."lits et places"n;
	by finess;
run;

proc sort data=XL_2018."lits et places"n;
	by finess;
run;

proc sort data=XL_2019."lits et places"n;
	by finess;
run;

/* Il y a des doublons dans les ID finess car la colonne indicateur contient plusieurs modalités.
On pourrait dépivoter les colonnes "indicateur" et "valeurs" pour avoir une colonne finess
sans doublon. Ce qui faciliterait l'analyse et la jointure entre plusieurs fichiers */


	/* Amélioration du fichier : On va réunir toutes les feuilles en un seul dataset */

/* 2017 */

proc sort data=XL_2017."LITS ET PLACES"n;
by finess;
run;

proc transpose data=XL_2017."LITS ET PLACES"n out=XL_2017."lits_transpose"n (drop = _name_ _label_);
by finess;
var Valeur;
id Indicateur;
run;

DATA XL_2017.data2017; 
  Merge XL_2017."lits_transpose"n XL_2017."Etablissement"n XL_2017."Activité Globale"n;
  BY finess; 
RUN;

data XL_2017.data2017;
set XL_2017.data2017;
year=2017;
run;

/* 2018 */

proc sort data=XL_2018."LITS ET PLACES"n;
by finess;
run;
proc transpose data=XL_2018."LITS ET PLACES"n out=XL_2018.lits_transpose (drop = _name_ _label_);
by finess;
var Valeur;
id Indicateur;
run;
DATA XL_2018.data2018; 
  Merge XL_2018."lits_transpose"n XL_2018."Etablissement"n XL_2018."Activité Globale"n;
  BY finess; 
RUN;
data XL_2018.data2018;
set XL_2018.data2018;
year=2018;
run;


/* 2019 */

proc sort data=XL_2019."LITS ET PLACES"n;
by finess;
run;

proc transpose data=XL_2019."LITS ET PLACES"n out=XL_2019.lits_transpose (drop = _name_ _label_);
by finess;
var Valeur;
id Indicateur;
run;

DATA XL_2019.data2019; 
  Merge XL_2019."lits_transpose"n XL_2019."Etablissement"n XL_2019."Activité Globale"n;
  BY finess; 
RUN;

data XL_2019.data2019;
set XL_2019.data2019;
year=2019;
run;

/*Regroupement des données des 3 années*/

DATA XL_2019.data_global_prep; 
  set XL_2017.data2017 XL_2018.data2018 XL_2019.data2019;
RUN;

	/* Modification des types de données, aidés par cf. Bibliographie du rapport */
	
* Récupérer le type de chaque variables et leurs noms;
proc contents
     data = XL_2019.data_global_prep
          noprint
     out = vars1 (keep = name type);
run; *Toutes les variables sont en varchar (type 2) sauf l'année;

proc sql;
     * On créer une liste qui va contenir les noms actuels des colonnes;
     
     select name
     into :numerics
          separated by ' '
     from vars1
     where type = 2
     and name not IN("finess","rs","cat","taille_MCO","taille_M","taille_C","taille_O","Indicateur","RH7","CI_A16_1","CI_A16_2","CI_A16_3","CI_A16_4"); *Variable dont on ne souhaite pas changer le type;

     * On créer une liste qui va contenir les noms actuels des colonnes avec un C en plus pour pouvoir remplacer par leurs noms de base;
     select trim(name) || 'C'
     into :characters
          separated by ' '
     from vars1
     where type = 2
     and name not IN("finess","rs","cat","taille_MCO","taille_M","taille_C","taille_O","Indicateur","RH7","CI_A16_1","CI_A16_2","CI_A16_3","CI_A16_4");
     
     * On créer une liste nom_colonne = nom_colonne_C;
     select cats(name, ' = ' , name, 'C')
     into :conversions
          separated by ' '
     from vars1
     where type = 2
     and name not IN("finess","rs","cat","taille_MCO","taille_M","taille_C","taille_O","Indicateur","RH7","CI_A16_1","CI_A16_2","CI_A16_3","CI_A16_4");
quit;

* On remplace les virgules par des points pour éviter les soucis de conversions;
data XL_2019.data_global;
	 set XL_2019.data_global_prep;
	 
	 array nums[*] &numerics;

     do i = 1 to dim(nums);
          nums[i] = tranwrd(nums[i], ',', '.');
     end;
run;

* Au lieu d'écrire nom_colonne = nom_colonne_C pour toutes les variables, on utilise notre liste créée précédemment;
data XL_2019.data_global;
	 set XL_2019.data_global;
     rename &conversions;
run;

* On change les types;
data XL_2019.data_global;
     set XL_2019.data_global;

     array nums[*] &numerics;
     array chars[*] &characters;

     do i = 1 to dim(nums);
          nums[i] = input(chars[i], BEST32.);
     end;
*On drop les colonnes avant la conversion;
     drop i &characters;
run;

	/*Détection des données manquantes*/

proc means data = XL_2019.data_global n nmiss;
  var _numeric_;
run;

	/*Détection des outliers*/

proc univariate data=XL_2019.data_global robustscale plot;
run; 

/*Détection doublons*/

proc sql;
   title 'Doublons';
   select finess, count(*) as Count
      from XL_2019.data_global
      group by finess
      having count(*) > 3;


/*-------------------------------------*/
/*------------ QUESTION 3 -------------*/
/*-------------------------------------*/


PROC TABULATE DATA = XL_2019.data_global ;
   CLASS year finess ;
   TABLE (year),
         (finess)*
         (N) ;
RUN ;

/*Analyse des établissements qui sont apparus : aucun*/

PROC SQL;
SELECT finess
FROM XL_2019.data_global
WHERE year = 2019
AND finess not in(SELECT finess FROM XL_2019.data_global WHERE year = 2017 OR year = 2018);
QUIT;


/*-------------------------------------*/
/*------------ QUESTION 4 -------------*/
/*-------------------------------------*/

/*Est-ce-que des établissements ont changé de taille: aucun*/

proc sql; 
    select finess,
    /*On regarde combien de modalités on trouve au sein de chaque variable*/
        count(distinct taille_MCO) as distinct_MCO,
        count(distinct taille_M) as distinct_M,
        count(distinct taille_C) as distinct_C,
        count(distinct taille_O) as distinct_O,
    /*Si on obtient une valeur > 1, l'établissement à changé au moins une fois de taille au cours des trois années*/
        max(count(distinct taille_MCO),count(distinct taille_M),count(distinct taille_C),count(distinct taille_O)) as max_code_different
    from XL_2019.data_global
    group by finess
    order by max_code_different asc;
quit;

/*Est-ce-que des établissements ont changé d'activité : oui */

proc sql; 
select finess, 
year, 
sum(CI_A1+ CI_A2+ CI_A3+ CI_A4+ CI_A5+ CI_A6+ CI_A7+ CI_A8+ CI_A9+ CI_A10+ CI_A11+ CI_A12+ CI_A13+ CI_A14+ CI_A15) as total_activite
from XL_2019.data_global
group by year, finess
order by finess;
quit;


/*-------------------------------------*/
/*------------ QUESTION 5 -------------*/
/*-------------------------------------*/

/*Taille_M : max = M5, min = M0, taille médecine     CI_AC1 (lits) & CI_AC5 (places) */
proc sql; 
select taille_M,min(CI_AC1) as min_lits, max(CI_AC1) as max_lits
from XL_2019.data_global
group by taille_M;
quit;

proc univariate;
var CI_AC1;
quit;

proc sql; 
select taille_M,min(CI_AC5) as min_places, max(CI_AC5) as max_places
from XL_2019.data_global
group by taille_M;
quit;

proc univariate;
var CI_AC5;
quit;


/*Taille_C : max = C5, min = C0, taille chirurgie    CI_AC6 (lits) & CI_AC7 (places) */
proc sql; 
select taille_C,min(CI_AC6) as min_lits, max(CI_AC6) as max_lits
from XL_2019.data_global
group by taille_C;
quit;

proc univariate;
var CI_AC6;
quit;

proc sql; 
select taille_C,min(CI_AC7) as min_places, max(CI_AC7) as max_places
from XL_2019.data_global
group by taille_C;
quit;

proc univariate;
var CI_AC7;
quit;


/*Taille_O : max = O5, min = O0, taille obstétrique    CI_AC8 (lits) & CI_AC9 (places) */
proc sql; 
select taille_O,min(CI_AC8) as min_lits, max(CI_AC8) as max_lits
from XL_2019.data_global
group by taille_O;
quit;

proc univariate;
var CI_AC8;
quit;

proc sql; 
select taille_O,min(CI_AC9) as min_places, max(CI_AC9) as max_places
from XL_2019.data_global
group by taille_O;
quit;

proc univariate;
var CI_AC9;
quit;


/*Quand on regarde le nombre de lits, on constate des valeurs abberantes, par ex des valeurs max plus grandes en M2 que en M3
On peut observer les proportions*/

proc sql; 
select finess,taille_M,CI_AC1 as nb_lits_med, (sum(CI_AC1)/(sum(CI_AC1)+sum(CI_AC6)+sum(CI_AC8)))*100 as part
from XL_2019.data_global
group by taille_M, finess
order by taille_M DESC;
quit;

/* Les résultats ne sont pas plus parlants */

/*-------------------------------------*/
/*------------ QUESTION 6 -------------*/
/*-------------------------------------*/

/*Création d'une nouvelle variable CI_ACTOT*/
data XL_2019.data_global;
set XL_2019.data_global;
CI_ACtot = sum(CI_AC1, CI_AC6, CI_AC8);
run;

/*Tableau croisé*/
PROC TABULATE DATA = XL_2019.data_global;
   class cat year;
   Var CI_AC1 CI_AC6 CI_AC8 CI_ACtot;
   tables cat='',year=''*(CI_AC1='Nb_lits_M'*(sum='') CI_AC6='Nb_lits_C'*(sum='') CI_AC8='Nb_lits_O'*(sum='') CI_ACtot='Total'*(sum=''));
RUN;


/*-------------------------------------*/
/*------------ QUESTION 7 -------------*/
/*-------------------------------------*/

/* Les départements d'outre-mer sont tous regroupés dans "97" et "98" */

/* Procédure SAS */

data XL_2019.data_global;
set XL_2019.data_global;
dep = substr(finess, 1, 2) ;
run;

PROC TABULATE DATA = XL_2019.data_global missing;
   class cat dep finess;
   tables dep='',cat=''*N='Nb Etab' N='Total';
RUN;

/* Procédure SQL*/

PROC SQL;
select dep,
count(distinct finess) as nb_etab,
cat
from XL_2019.data_global
group by dep, cat;
QUIT;


/*-------------------------------------*/
/*------------ QUESTION 8 -------------*/
/*-------------------------------------*/

/* Tableau */
	/* Procédure SAS */
PROC TABULATE DATA = XL_2019.data_global missing;
   class cat CI_E6;
   Var CI_A11 CI_AC8;
   where sum(CI_A11) > 0 or sum(CI_AC8) > 0; /*Avoir uniquement les établissement qui pratiquent une activité obstétrique*/
   tables cat='Catégorie'*CI_E6='Etape Maternité',(CI_A11='Nb_Accouchements'*(sum='') CI_AC8='Nb_Lits_Obstétriques'*(sum=''));
RUN;

	/* Procédure SQL */
PROC SQL;
select cat,
CI_E6,
sum(CI_A11) as nb_accouchement,
sum(CI_AC8) as nb_lits_obstetrique
from XL_2019.data_global
group by cat, CI_E6
having SUM(CI_A11) > 0 and SUM(CI_AC8) > 0 /*Avoir uniquement les établissement qui pratiquent une activité obstétrique*/
order by cat;
QUIT;


/* TOP 5 des établissement avec la plus forte activité obstétrique */
PROC SQL OUTOBS=5;
select finess,
sum(CI_A11) as nb_accouchement,
sum(CI_AC8) as nb_lits_obstetrique
from XL_2019.data_global
group by finess
order by nb_accouchement desc, nb_lits_obstetrique desc;
QUIT; 

/*-------------------------------------*/
/*------------ QUESTION 9 -------------*/
/*-------------------------------------*/

	/* Procédure SQL */
PROC SQL;
select dep,
sum(CI_A11) as nb_accouchement,
sum(CI_AC8) as nb_lits_obstetrique,
min(CI_A11) as min_nb_accouchement,
max(CI_A11) as max_accouchement
from XL_2019.data_global
group by dep
order by nb_accouchement desc, nb_lits_obstetrique desc;
QUIT;


/*--------------------------------------*/
/*------------ QUESTION 10 -------------*/
/*--------------------------------------*/

/*Création de nouvelles variables pour les établissements dont on dispose de certaines données et qui ont eu au moins 12 naissances par an*/
data XL_2019.data_acc(where=(CI_A11>12)); 
set XL_2019.data_global;
where CI_RH5>0 and CI_AC8>0;
Lit_par_acc = CI_AC8/CI_A11; /* Nb Lits Obsté / Nb d'accouchement */
Temps_plein_par_acc = CI_RH5/CI_A11; /* Nb Gynécologues/ Nb d'accouchement */
RUN;

/*Standard-normaliser pour obtenir un score de qualité*/
PROC STANDARD DATA=XL_2019.data_acc MEAN=0 STD=1 OUT=XL_2019.data_acc;
  VAR Lit_par_acc Temps_plein_par_acc ;
RUN;

/*Création du score à partir des variables standardisés*/
Data XL_2019.data_acc;
set XL_2019.data_acc;
score_qual = ((Lit_par_acc + Temps_plein_par_acc)/2)*100;
Run;

/*5 meilleurs établissements selon notre score de qualité*/
PROC SQL OUTOBS=5;
SELECT finess, rs,
avg(CI_RH5) as temps_plein_obst,
avg(CI_AC8) as nb_lits,
avg(CI_A11) as nb_accouchement,
avg(score_qual) as score_qual
from XL_2019.data_acc
group by finess,rs
order by score_qual desc;
QUIT;

/*5 pires établissements selon notre score de qualité*/
PROC SQL OUTOBS=5;
SELECT finess, rs,
avg(CI_RH5) as temps_plein_obst,
avg(CI_AC8) as nb_lits,
avg(CI_A11) as nb_accouchement,
avg(score_qual) as score_qual
from XL_2019.data_acc
group by finess,rs
order by score_qual asc;
QUIT;


/*-------------------------------------*/
/*------------ QUESTION 11 ------------*/
/*-------------------------------------*/


/*Etablissements avec les plus grandes différences d'une année par rapport à une autre*/
PROC SQL OUTOBS=5;
SELECT finess,
MAX(score_qual)-MIN(score_qual) as diff
from XL_2019.data_acc
group by finess
order by diff desc;
QUIT;

/*Etude d'établissements avec les plus grandes différences*/
PROC SQL;
SELECT finess,rs,year,CI_AC8,CI_A11,CI_ACtot,Lit_par_acc,Temps_plein_par_acc,score_qual
FROM XL_2019.data_acc
WHERE finess = "970107249";
QUIT;

PROC SQL;
SELECT finess,rs,year,CI_AC8,CI_A11,CI_ACtot,Lit_par_acc,Temps_plein_par_acc,score_qual 
FROM XL_2019.data_acc
WHERE finess = "970100178";
QUIT;


/*-------------------------------------*/
/*------------ QUESTION 12 ------------*/
/*-------------------------------------*/

	/* Procédure SAS */
PROC TABULATE DATA = XL_2019.data_acc missing;
   class dep year;
   Var score_qual;
   tables dep='Dep',year='Année'*(score_qual='Score_Qual'*(mean=''));
RUN;

	/* Procédure SQL */
PROC SQL;
SELECT dep, year, avg(score_qual) as score_qual
from XL_2019.data_acc
group by dep, year;
QUIT;	
