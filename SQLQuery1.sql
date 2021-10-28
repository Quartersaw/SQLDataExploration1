select *
from PortfolioProject..covidDeaths
order by location, date;

-- The first 3 columns have imported with double quotes around all of the entries.
-- Let's clean that up.
Update PortfolioProject..covidDeaths
Set iso_code = replace(iso_code,'"', ''),
continent = replace(continent, '"', ''),
location = replace(location, '"', '');

-- Convert the NA entries from strings to nulls.
Update PortfolioProject..covidDeaths
set total_cases = NULL where total_cases = 'NA';

update PortfolioProject..covidDeaths
set total_deaths = null where total_deaths = 'NA';

-- Select the data that we are going to be using.
select location, date, total_cases, total_deaths, population
from PortfolioProject..covidDeaths
order by location, date;

-- Looking at total cases versus total deaths.
-- In order to prevent integer division, I'm casting one of the columns as a float.
select location, date, total_cases, total_deaths, CAST(total_deaths as float) / total_cases * 100 as deathPercentage
from PortfolioProject..covidDeaths
where location like '%states%'
order by location, date;

-- Looking at total cases versus population
select location, date, population, total_cases, CAST(total_cases as float) / population * 100 as percentPopulationInfected
from PortfolioProject..covidDeaths
where location like '%states%'
order by location, date;

-- Turn NA's into nulls in order to convert population's data type from varchar to float.
update PortfolioProject.dbo.covidDeaths
set population = null where population = 'NA';

-- What countries have the highest infection rate?
select location, population, max(total_cases) as highestInfectionCount, max(total_cases / population) * 100 as percentPopulationInfected
from PortfolioProject..covidDeaths
group by location, population
order by percentPopulationInfected desc;

-- Base data includes World and Continent data
-- These have the continent set to NA.
-- Change NA to null for filtering purposes.
update PortfolioProject.dbo.covidDeaths
set continent = null where continent = 'NA';

-- Death rate by continent.
select continent, max(total_deaths) as totalDeathCount
from PortfolioProject..covidDeaths
where continent is not null
group by continent
order by totalDeathCount desc;

-- Highest death count by continent.
select continent, max(total_deaths) as totalDeathCount
from PortfolioProject..covidDeaths
where continent is not null
group by continent
order by totalDeathCount desc;

-- Global deaths by date.
update PortfolioProject..covidDeaths
set new_cases = null, new_deaths = null
where new_cases = 'NA' or new_deaths = 'NA';

select date, sum(new_cases) as globalCases, sum(new_deaths) as globalDeaths, sum(cast(new_deaths as float))/sum(new_cases)*100 as globalDeathPercentage
from PortfolioProject..covidDeaths
where continent is not null
group by date
order by date;

-- Covid Vaccination data.
select *
from PortfolioProject..[owid-covid-data]
order by location, date;

-- Total deaths versus vaccinations.
select deaths.continent, deaths.location, deaths.date, deaths.population, vaccs.new_vaccinations,
	sum(cast(vaccs.new_vaccinations as float)) over(partition by deaths.location order by deaths.location, deaths.date) as rollingVaccinations
from PortfolioProject..covidDeaths deaths
join PortfolioProject..[owid-covid-data] vaccs
on deaths.location = vaccs.location
and deaths.date = vaccs.date
where deaths.continent is not null
order by location, date;

-- Using a CTE to shorthand rollingVaccinations:
with popVsVax( continent, location, date, population, new_vaccinations, rollingVaccinations)
as (
	select deaths.continent, deaths.location, deaths.date, deaths.population, vaccs.new_vaccinations,
		sum(convert(float, vaccs.new_vaccinations)) over(partition by deaths.location order by deaths.location, deaths.date) as rollingVaccinations
	from PortfolioProject..covidDeaths as deaths
	join PortfolioProject..[owid-covid-data] as vaccs
	on deaths.location = vaccs.location
	and deaths.date = vaccs.date
	where deaths.continent is not null
	)
select *, (rollingVaccinations/population) * 100 as percentVaccinated
from popVsVax;

-- Using a temp table to shorthand rollingVaccinations:
drop table if exists percentPopulationVaccinated
create table percentPopulationVaccinated
(	continent nvarchar(255),
	location nvarchar(255),
	date datetime, 
	population numeric,
	new_vaccinations numeric,
	rollingVaccinations numeric
)
insert into percentPopulationVaccinated
	select deaths.continent, deaths.location, deaths.date, deaths.population, cast(vaccs.new_vaccinations as float),
		sum(convert(float, vaccs.new_vaccinations)) over(partition by deaths.location order by deaths.location, deaths.date) as rollingVaccinations
	from PortfolioProject..covidDeaths as deaths
	join PortfolioProject..[owid-covid-data] as vaccs
	on deaths.location = vaccs.location
	and deaths.date = vaccs.date
	where deaths.continent is not null

select *, (rollingVaccinations/population) * 100 as percentVaccinated
from percentPopulationVaccinated;

-- Create a view for later visualization.
create view vaccinatedPercentage as
	select deaths.continent, deaths.location, deaths.date, deaths.population, vaccs.new_vaccinations,
		sum(convert(float, vaccs.new_vaccinations)) over(partition by deaths.location order by deaths.location, deaths.date) as rollingVaccinations
	from PortfolioProject..covidDeaths as deaths
	join PortfolioProject..[owid-covid-data] as vaccs
	on deaths.location = vaccs.location
	and deaths.date = vaccs.date
	where deaths.continent is not null;