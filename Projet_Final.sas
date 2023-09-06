/* ----------------------------------------- */
/* -- PARTIE 1 : PREPARATION DES DONNEES --  */
/* ----------------------------------------- */

/* 1. ---- Création de la librairie ----*/

options validvarname=any; /*Evite les erreurs de conversions dans les noms de variables*/
LIBNAME Projet '/home/u62478841/Projet_Accident';

/* ---- Import des CSV ----*/

proc import out=Projet.carac
    datafile='/home/u62478841/Projet_Accident/carcteristiques-2021.csv'
    dbms=csv
    replace;
    delimiter=";";
    getnames=YES;
run;

proc import out=Projet.lieux
    datafile='/home/u62478841/Projet_Accident/lieux-2021.csv'
    dbms=csv
    replace;
    delimiter=";";
    getnames=YES;
run;

proc import out=Projet.usagers
    datafile='/home/u62478841/Projet_Accident/usagers-2021.csv'
    dbms=csv
    replace;
    delimiter=";";
    getnames=YES;
run;

proc import out=Projet.veh
    datafile='/home/u62478841/Projet_Accident/vehicules-2021.csv'
    dbms=csv
    replace;
    delimiter=";";
    getnames=YES;
run;

/* --- Jointure des fichiers --- */
	
	/*Proc sort pour faire les jointures*/
	
PROC SORT data = Projet.carac;
by Num_Acc;
RUN;

PROC SORT data = Projet.lieux;
by Num_Acc;
RUN;

PROC SORT data = Projet.veh;
by Num_Acc id_vehicule; /*On ajoute l'id_vehicule car un accident peut concerner plusieurs véhicules */ 
RUN;

PROC SORT data = Projet.usagers;
by Num_Acc id_vehicule;
RUN;

	/*Jointures*/
	
DATA Projet.data_prep; 
  Merge Projet.carac Projet.lieux Projet.veh;
  BY Num_Acc; 
RUN;

DATA Projet.data_global;
	Merge Projet.data_prep Projet.usagers;
	BY Num_Acc id_vehicule;
RUN;

/* 2. --- Traitement des données ---*/

	/* Remplacer les -1 par des null */

data Projet.data_global;
set Projet.data_global;
array Var _CHARACTER_; /*On prend toutes les variables en varchar*/
            do over Var;
            if Var=-1 then Var=.;
            end;
run ;

	/* Changement des types */

proc contents
     data = Projet.data_global
          noprint
     out = vars1 (keep = name type);
run;

proc sql /* noprint */;

     select name
     into :numerics
          separated by ' '
     from vars1
     where name in("lat","long","nbv","pr1","lartpc","larrout","vma","occutc","jour");

* On créer une liste qui va contenir les noms actuels des colonnes avec un C en plus pour pouvoir remplacer par leurs noms de base;
     select trim(name) || 'C'
     into :characters
          separated by ' '
     from vars1
     where name in("lat","long","nbv","pr1","lartpc","larrout","vma","occutc","jour");

     * On créer une liste nom_colonne = nom_colonne_C;
     select cats(name, ' = ' , name, 'C')
     into :conversions
          separated by ' '
     from vars1
     where name in("lat","long","nbv","pr1","lartpc","larrout","vma","occutc","jour");

     quit;

* On remplace les virgules par des points pour éviter les soucis de conversions;
data Projet.data_global;
	 set Projet.data_global;
	 
	 array nums[*] &numerics;

     do i = 1 to dim(nums);
          nums[i] = tranwrd(nums[i], ',', '.');
     end;
run;

* Au lieu d'écrire nom_colonne = nom_colonne_C pour toutes les variables, on utilise notre liste créée précédemment;
data Projet.data_global;
	 set Projet.data_global;
     rename &conversions;
run;

* On change les types;
data Projet.data_global;
     set Projet.data_global;

     array nums[*] &numerics;
     array chars[*] &characters;

     do i = 1 to dim(nums);
          nums[i] = input(chars[i], BEST32.);
     end;
*On drop les colonnes avant la conversion;
     drop i &characters;
run;

	/*Suppression des doublons*/

proc sort data=Projet.data_global out=Projet.data_global nodupkey;
    by _all_;
run;

	/*Détection des outliers*/
proc univariate data=Projet.data_global robustscale plot;
run;

/*Analyse d'une valeur extrême pour la variable lartpc*/
proc sql;
select *
from Projet.data_global
where lartpc = 40;
quit;

/* ----------------------------------------- */
/* ---- PARTIE 2 : ANALYSE DESCRIPTIVE ----  */
/* ----------------------------------------- */

/*Il faut garder en tête qu'on aura un nombre d'accident plus
élevé au moment ou il y a le plus de conducteur. 
Si on pouvait diviser le nombre d'accident pour chaque modalité par 
le nombre moyen de véhicule sur la route on aurait alors un taux d'accident plus parlant.
L'infos du nombre de conducteur moyen n'est cependant pas disponible dans notre dataset.*/

/* --- 1. Nombre d'accidents par département et par localisation ---*/
/* PROC SAS */

PROC TABULATE DATA = Projet.data_global;
   class dep agg;
   tables dep='', N = 'Nb_accident'*agg='Agglomeration' N='Total';
RUN;

/* PROC SQL */
/* Départements avec le plus d'accidents */
PROC SQL;
title 'Départements avec le plus d''accidents';
SELECT dep,
count(distinct Num_acc) as nb_accidents
from Projet.data_global
group by dep
order by nb_accidents desc;
QUIT;

/* Plus d'accidents en agglomération que hors agglomération */
PROC SQL;
SELECT count(distinct Num_acc) as nb_accidents,
agg
from Projet.data_global
group by agg
order by nb_accidents desc;
QUIT;


/* --- 2. Est-ce-que les conditions d'environnement ont un impact sur le nombre d'accidents ? --- */

        /*Nombre d'accident en fonction de la luminosité*/
/*data*/
proc sql;
create table Projet.data_lum as
	select 
	case when lum = '1' then 'Plein jour'
	     when lum = '2' then 'Crépuscule ou aube'
	     when lum = '3' then 'Nuit sans éclairage public'
	     when lum = '4' then 'Nuit avec éclairage public éteint'
	     when lum = '5' then 'Nuit avec éclairage public allumé'
	end as lum_nom,
	count(distinct(Num_Acc)) as nb_accidents
	from Projet.data_global
	group by lum_nom;
quit;   

/*graphique*/
proc template;
	define statgraph SASStudio.Pie;
		begingraph;
		entrytitle "Répartition du nombre d'accidents selon la condition d'éclairage" 
			/ textattrs=(size=14); /*Taille du titre*/ 
		layout region;
		piechart category=lum_nom response=nb_accidents / datalabellocation=callout 
			datalabelattrs=(size=8); /*Taille police des libellés*/
		endlayout;
		endgraph;
	end;
run;

ods graphics / reset width=6.4in height=4.8in imagemap;

proc sgrender template=SASStudio.Pie data=PROJET.DATA_LUM;
run;


        /*Nombre d'accident en fonction de la météo*/
PROC TABULATE DATA = Projet.data_global;
   title '% d''accidents en fonction de la météo';
   class atm;
   keylabel pctn = " " ; /*Supprime l'en-tête PCTN*/
   tables atm='Conditions météorologiques' * pctn;
RUN;
        /*Nombre d'accident en fonction de l'état du sol*/
PROC TABULATE DATA = Projet.data_global;
   title '% d''accidents en fonction de l''état de la route';
   class surf;
   keylabel pctn = " " ; /*Supprime l'en-tête pctn*/
   tables surf='Etat de la route' * pctn;
RUN;

        /*Nombre d'accident en fonction du mois*/
/*Data*/
proc sql;
create table Projet.data_mois as
	select 
	case when grav = '1' then 'Indemne'
	     when grav = '2' then 'Tué'
	     when grav = '3' then 'Blessé hospitalisé'
	     when grav = '4' then 'Blessé leger'
	     else 'Etat inconnu'
	end as grav_nom,
	mois,
	count(distinct(Num_Acc)) as nb_accidents
	from Projet.data_global
	group by grav_nom, mois;
quit;  

/*Graphique*/
ods graphics / reset width=6.4in height=4.8in imagemap;

proc sgplot data=PROJET.DATA_MOIS;
	title height=14pt 
		"Evolution mensuelle du nombre d'accidents par niveau de gravité";
	vline mois / response=nb_accidents group=grav_nom datalabel;
	yaxis grid;
run;

ods graphics / reset;
title;


/* --- 3. Représenter graphiquement les lieux où se sont produits les accidents ---*/

/*Data*/
data Projet.metropole;
        set Projet.data_global;
        KEEP long lat;
        WHERE dep not like '971' and dep not LIKE '972' and dep not LIKE '973' and dep not LIKE '974' and dep not LIKE '975' and dep not LIKE '976' and dep not LIKE '977' and dep not LIKE '978' and dep not LIKE '986' and dep not LIKE '987' and dep not LIKE '988' ;
run;

/*Graphique*/
ods graphics / reset width=8in height=6.9in;
proc sgmap plotdata=Projet.metropole;
        openstreetmap;
        title 'Cartographie des accidents de voiture';
        scatter x=long y=lat/ markerattrs=(size=1 color=CXd31e1e);
run;
ods graphics / reset;
title;


/* ----------------------------------------- */
/* --- PARTIE 3 : ANALYSE INFERENTIELLE ---  */
/* ----------------------------------------- */

/* 1. --- Test d'indépendance entre deux variables qualitatives --- */

/*    Var1 : catu (catégorie usager 1: Conducteur, 2: Passager, 3: Piéton)
	  Var2 : grav (gravité de l'accident 1: Indemne, 2: Tué, 3: Blessé Hospitalisé, 4: Bléssé Léger)

  Nous allons réaliser un test du Khi-deux avec les hypothèses suivantes :
	H0 : Il existe un lien entre la catégorie de l'usager et la gravité de l'accident
	H1 : Il n'existe pas de lien

    Tout d'abord, on catégorise nos données pour qu'elles aient le même nombre de modalités.
On va regrouper la modalité 1 et 4 de la variable grav dans un groupe "Accident léger", et les
modalités 2 et 3 dans "Accident grave". De même, nous allons exclure les piétions de l'analyse. 

*/

data Projet.data_khideux;
	 set Projet.data_global;
	 
	 KEEP Num_Acc id_vehicule catu_nom cate_grav;

	 IF grav = '1' THEN cate_grav = 'Accident leger';
	 ELSE IF grav = '4' THEN cate_grav = 'Accident leger';
	 ELSE IF grav = '2' THEN cate_grav = 'Accident grave';
	 ELSE IF grav = '3' THEN cate_grav = 'Accident grave';
	 
	 IF catu = '1' THEN catu_nom = 'Conducteur';
	 ELSE IF catu = '2' THEN catu_nom = 'Passager';
	 
	 WHERE (grav = '1' OR grav = '2' OR grav = '3' OR grav = '4')
	 AND (catu = '1' OR catu = '2');
	 
run;

proc freq data = Projet.data_khideux;
tables catu_nom*cate_grav /chisq EXPECTED DEVIATION NOROW NOCOL ;
/* On affiche les effectifs théoriques et les écarts 
Si l'effectif observé est supérieur à l'effectif théorique, 
on peut supposer que les deux modalités étudiées ne sont pas indépendantes.*/
run;


/* 2. --- ANOVA --- */
/*Création d'un dataframe avec uniquement les données concernées*/
/*On prend les département où il y a le plus d'accidents*/

proc sql;
	Create Table Projet.Data_ANOVA as 
		Select count(distinct(Num_Acc)) as nb_accidents,
		dep,
		case when sexe = '1' then 'Homme'
		     when sexe = '2' then 'Femme'
		end as sexe_name
		from Projet.Data_global
		where dep in ('75','93','13','94','69','92','91','33','59','95')
		and sexe in ('1','2')
		group by dep, sexe_name
		order by dep;
quit;

PROC ANOVA DATA=Projet.Data_ANOVA ;
     CLASS sexe_name ;
     MODEL nb_accidents=sexe_name ;


/* ----------------------------------------- */
/* ------ PARTIE 4 : Autres analyses ------  */
/* ----------------------------------------- */

/* --- Communes avec le plus d'accidents --- */
PROC SQL OUTOBS=15;
SELECT 
com,
count(distinct Num_Acc) as nb_accidents
from Projet.data_global
group by com
order by nb_accidents desc;
QUIT;

/* --- Nombre d'accidents, de véhicules et de victimes recensés ---*/
PROC SQL;
SELECT count(distinct Num_acc) as nb_accidents,
count(distinct id_vehicule) as nb_vehicules,
count(id_vehicule) as nb_victimes
from Projet.data_global;
QUIT;

/* --- Nombre d'accidents selon le jour du mois --- */
proc SQL;
select 
jour,
count(distinct(Num_Acc)) as nb_accidents
from Projet.data_global
group by jour
order by nb_accidents DESC;
quit;

/* Décomposition des gravités de blessure selon la catégorie de victime (en %)*/
Data Projet.data_gravite_cat;
Set Projet.data_global(rename=(Num_acc=Num_acc_old));
Num_acc =  INPUT(Num_acc_old,f8.);
drop Num_acc_old;
RUN;

PROC TABULATE DATA = data_gravite_cat;
   class catu grav;
   Var Num_acc;
   tables catu='Catégorie usager',grav='gravité'*(Num_acc=''*(ROWPCTN=''));
RUN;
