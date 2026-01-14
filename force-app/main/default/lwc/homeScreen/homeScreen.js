import { LightningElement,track } from 'lwc';
import getApexData from '@salesforce/apex/beatPlannerlwc.getData';
import GOOGLE_ICONS from '@salesforce/resourceUrl/googleIcons';
//import ChartJs from '@salesforce/resourceUrl/ChartJS';-->
import { loadScript } from 'lightning/platformResourceLoader';

export default class HomeScreen extends LightningElement {
 
    visitIcon = {
        Productivity : GOOGLE_ICONS + "/googleIcons/Productivity.png",
        visit :  GOOGLE_ICONS + "/googleIcons/visit.png",
        daySummery :  GOOGLE_ICONS + "/googleIcons/daySummery.png",
        overallSummery :  GOOGLE_ICONS + "/googleIcons/overallSummery.png",
        expense :  GOOGLE_ICONS + "/googleIcons/expense.png",
        achive :  GOOGLE_ICONS + "/googleIcons/achive.png",
    };
    chart ;

    @track isDropdownTargetOpen = false;
    @track isDropdownExpenseOpen = false;
    @track isDropdownDayOpen = false;
    @track isDropdownProOpen = false;
    @track isVisitDropdownOpen = false;
    @track isPresent = false;
    @track offSet = 0;
    @track Limit = 5;
    @track targetData = []; // Array to store the loaded data
    @track ExpenseData = [];
    @track graphData = [];
    @track visitData = [];
    @track productive = [];
    @track productiveToday = [];
    @track mapMarkers;
    @track placeholders = [];
    @track chartInitialized = false;
    isPageLoaded = true;
    
    zoomLevel = 15;
    listView = 'visible';
    isSpinner = false;
    isDataLoaded = false; isDropdownAchiveOpen = false; myTargets = true; 
    myDaySummary = true; myProductivity = true; myVisits = true; myExpense = true; myAchivements = true;
    targerHeading = ['Target','Planned','Actual','Achieved%'];
    visitHeading = ['Visit','Account Name','Status','Actual Start date/time','Actual End date/time'];
    

    connectedCallback(){
        this.isDropdownTargetOpen = true; 
        this.isDropdownDayOpen = true;
        this.offSet = 0;
        this.getAttendanceData('My Target',null);
        this.getAttendanceData('getOrderProductivityforToday',null);
        //this.getAttendanceData('Expense',null);
    }
    setChartJs(){

        loadScript(this, ChartJs)
        .then(() => {
            this.initializeChart();
        })
        .catch(error => {
            console.error('Error loading Chart.js:', error);
        });
    }

    initializeChart() { 
        const dta = this.graphData; 
    
        var data = {
            label : [],
            actual : [],
            target : []
        }
        for(let i=0 ;i<dta.length; i++){
            data.label.push(dta[i].xAxis);
            data.actual.push(dta[i].actual);
            data.target.push(dta[i].target);
        }
        const ctx = this.template.querySelector('canvas').getContext('2d');
        this.chart = new Chart(ctx, {
            type: 'bar', // Default type (main chart type)
            data: {
                labels: data.label,
                datasets: [
                    {
                        type: 'bar', // Bar dataset
                        label: 'Actual',
                        data: data.actual,
                        backgroundColor: 'rgba(75, 192, 192, 0.2)',
                        borderColor: 'rgba(75, 192, 192, 1)',
                        borderWidth: 1
                    },
                    {
                        type: 'line', // Line dataset
                        label: 'Target',
                        data: data.target,
                        backgroundColor: 'rgba(255, 99, 132, 0.2)',
                        borderColor: 'rgba(255, 99, 132, 1)',
                        borderWidth: 2,
                        fill: false
                    }
                ]
            },
            options: {
                responsive: true,
                plugins: {
                    legend: {
                        position: 'top',
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true
                    }
                }
            }
        });
    }
    
    get currentMonthYear() {
        // Get the current date
        const today = new Date();
        
        // Array of month names
        const monthNames = [
            "January", "February", "March", "April", "May", "June", 
            "July", "August", "September", "October", "November", "December"
        ];

        // Get the current month name and year
        const monthName = monthNames[today.getMonth()];
        const year = today.getFullYear();

        // Return the formatted string
        return `${monthName} ${year}`;
    }

    formatDate(date) {
        const year = date.getFullYear();
        const month = (date.getMonth() + 1).toString().padStart(2, '0'); // Month starts from 0
        const day = date.getDate().toString().padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    // Fetching attendance data with offset and limit
    getAttendanceData(obj,dateValue) {

        this.isSpinner = true;
        let todayDate;
        if(dateValue != null){
            todayDate =this.formatDate(new Date());
        }
        
        
        getApexData({ 
            isoffSet: this.offSet,
            isLimit: this.Limit,
            objName : obj,
            fromDate : todayDate,
            toDate : todayDate
        })
        .then(result => {
            if(obj == 'My Target'){
                if(result.kpi.targlist.length != 0){
                    this.targerValueSet(result);
                    if(result.kpi.graphlist != undefined){
                        this.graphData = result.kpi.graphlist;
                    }
                }else{
                    this.targetData = null;
                } 
            }
            else if(obj == 'Expense'){
                this.ExpenseValueSet(result);
            }
            else if(obj == 'BeatPlan'){
                this.visitValueSet(result);
            }
            else if(obj == 'getOrderProductivityforMonth'){
                if(result.productive.length != 0){
                    this.OrderProductivityValueSet(result);
                }else{
                    this.productive = null;
                }
            }
            else if(obj == 'getOrderProductivityforToday'){
                this.OrderProductivityTodayValueSet(result);
            }
            this.isSpinner = false;
            this.isPageLoaded = false;
        })
        .catch(error => {
            console.error(error);
            this.isSpinner = false;
        });
    }
    OrderProductivityValueSet(result){
        this.productive = result.productive;
    }
    OrderProductivityTodayValueSet(result){
        this.productiveToday = result;
    }
    visitValueSet(result){

        this.visitData = result.visit;
        const visData =  result.visit;
        let mapMarkersPoints = [];
        visData.forEach(vis => {
            if(vis.ClockoutLongitude && vis.ClockoutLatitude){
                mapMarkersPoints.push({
                    location: {
                        Latitude: vis.ClockoutLatitude,
                        Longitude: vis.ClockoutLongitude
                    }
                });
            }
        });
        if(mapMarkersPoints != null){
            this.mapMarkers = mapMarkersPoints;
        }
    }
    targerValueSet(result){
        if (result && result.kpi && result.kpi.targlist) {
            this.isDataLoaded = true;
            // Append the newly loaded data to the targetData array
            const target = result.kpi.targlist;
            //this.targetData = target;
            this.targetData = [...this.targetData, ...target];
            
        }
    }
    ExpenseValueSet(result){
        this.ExpenseData = result.expense;
    }
    toggleVisitDropdown(){
        this.isVisitDropdownOpen = !this.isVisitDropdownOpen;
        const dropdownBody = this.template.querySelector('.dropdown-body-visit');
        const chevronIcon = this.template.querySelector('.chevron-icon-visit');
        if (dropdownBody) {
            if (this.isVisitDropdownOpen) {
                dropdownBody.classList.add('active');
                chevronIcon.iconName = 'utility:chevronup'; // Switch to chevron up
                if(this.visitData.length == 0){
                    this.offSet = 0;
                    this.getAttendanceData('BeatPlan','This_Day');

                }
            } else {
                dropdownBody.classList.remove('active');
                chevronIcon.iconName = 'utility:chevrondown'; // Switch back to chevron down
            }
        }
    }
    toggleDayDropdown(){
        this.isDropdownDayOpen = !this.isDropdownDayOpen; // Toggles the boolean value
        const dropdownBody = this.template.querySelector('.dropdown-body-day');
        const chevronIcon = this.template.querySelector('.chevron-icon-day');

        if (dropdownBody) {
            if (this.isDropdownDayOpen) {
                dropdownBody.classList.add('active');
                chevronIcon.iconName = 'utility:chevronup'; // Switch to chevron up
                if(this.ExpenseData.length == 0){
                    this.offSet = 0;
                    this.getAttendanceData('Expense',null);

                }
            } else {
                dropdownBody.classList.remove('active');
                chevronIcon.iconName = 'utility:chevrondown'; // Switch back to chevron down
            }
        }
    }

    toggleProductiveDropdown(){
        this.isDropdownProOpen = !this.isDropdownProOpen; // Toggles the boolean value
        const dropdownBody = this.template.querySelector('.dropdown-body-pro');
        const chevronIcon = this.template.querySelector('.chevron-icon-pro');

        if (dropdownBody) {
            if (this.isDropdownProOpen) {
                dropdownBody.classList.add('active');
                chevronIcon.iconName = 'utility:chevronup'; // Switch to chevron up
                if(this.productive.length == 0){
                    this.offSet = 0;
                    this.getAttendanceData('getOrderProductivityforMonth',null);

                }
            } else {
                dropdownBody.classList.remove('active');
                chevronIcon.iconName = 'utility:chevrondown'; // Switch back to chevron down
            }
        }
    }
    toggleAchiveDropdown() {
        this.isDropdownAchiveOpen = !this.isDropdownAchiveOpen; // Toggles the boolean value
        const dropdownBody = this.template.querySelector('.dropdown-body-achive');
        const chevronIcon = this.template.querySelector('.chevron-icon-achive');

        if (dropdownBody) {
            if (this.isDropdownAchiveOpen) {
  
                dropdownBody.classList.add('active');
                chevronIcon.iconName = 'utility:chevronup'; // Switch to chevron up
                if(this.targetData.length != 0){
                    this.setChartJs();
                }else{
                    this.offSet = 0;
                    this.getAttendanceData('My Target',null);
                }
            } else {
                dropdownBody.classList.remove('active');
                chevronIcon.iconName = 'utility:chevrondown'; // Switch back to chevron down
            }
        }
    }

    
    toggleTargetDropdown() {
        this.isDropdownTargetOpen = !this.isDropdownTargetOpen; // Toggles the boolean value
        const dropdownBody = this.template.querySelector('.dropdown-body');
        const chevronIcon = this.template.querySelector('.chevron-icon');

        if (dropdownBody) {
            if (this.isDropdownTargetOpen) {
  
                dropdownBody.classList.add('active');
                chevronIcon.iconName = 'utility:chevronup'; // Switch to chevron up
                if(this.targetData.length == 0){
                    this.offSet = 0;
                    this.getAttendanceData('My Target',null);

                }
            } else {
                dropdownBody.classList.remove('active');
                chevronIcon.iconName = 'utility:chevrondown'; // Switch back to chevron down
            }
        }
    }

    toggleExpenseDropdown(){
        this.isDropdownExpenseOpen = !this.isDropdownExpenseOpen; // Toggles the boolean value
        const dropdownBody = this.template.querySelector('.dropdown-body-ex');
        const chevronIcon = this.template.querySelector('.chevron-icon-ex');

        if (dropdownBody) {
            if (this.isDropdownExpenseOpen) {
                dropdownBody.classList.add('active');
                chevronIcon.iconName = 'utility:chevronup'; // Switch to chevron up
                if(this.ExpenseData.length == 0){
                    this.offSet = 0;
                    this.getAttendanceData('Expense',null);

                }
            } else {
                dropdownBody.classList.remove('active');
                chevronIcon.iconName = 'utility:chevrondown'; // Switch back to chevron down
            }
        }
    }

    loadMoreTarget() {
        this.offSet += this.targetData.length + 5;
        //this.offSet += this.Limit; // Increase the offset to load the next set of data
        this.getAttendanceData('My Target',null); // Fetch more data
    }
    openMapLocation(){
        if (this.mapMarkers.length > 0) {
            // Create an array to store latitude and longitude pairs for all markers
            let waypoints = [];
            this.mapMarkers.forEach(marker => {
                const latitude = marker.location.Latitude;
                const longitude = marker.location.Longitude;
                waypoints.push(`${latitude},${longitude}`);
            });

            // Join waypoints with '|' separator for Google Maps URL
            const waypointString = waypoints.join('|');

            // Construct the Google Maps URL with multiple markers
            //const googleMapsUrl = `https://www.google.com/maps/dir/?api=1&waypoints=${waypointString}`;

            // Open the URL in a new tab
            window.open(googleMapsUrl, '_blank');
        } else {
            // Handle case when no map markers are available
            console.log('No map markers available');
        }
    }

    isExpandForm(event){
        const name = event.currentTarget.dataset.name;
        if(name === 'target'){
            this.myAchivements = !this.myAchivements;
            this.myDaySummary = !this.myDaySummary;
            this.myProductivity = !this.myProductivity;
            this.myExpense = !this.myExpense;
            this.myVisits = !this.myVisits;
            if(!this.isDropdownTargetOpen){
                this.toggleTargetDropdown();
            }
        }
        else if(name === 'achivement'){
            this.myTargets = !this.myTargets;
            this.myDaySummary = !this.myDaySummary;
            this.myProductivity = !this.myProductivity;
            this.myExpense = !this.myExpense;
            this.myVisits = !this.myVisits;
            if(!this.isDropdownAchiveOpen){
                this.toggleAchiveDropdown();
            }
        }
        else if(name === 'summary'){
            this.myTargets = !this.myTargets;
            this.myAchivements = !this.myAchivements;
            this.myProductivity = !this.myProductivity;
            this.myExpense = !this.myExpense;
            this.myVisits = !this.myVisits;
            if(!this.isDropdownDayOpen){
                this.toggleDayDropdown();
            }
        }
        else if(name === 'productivity'){
            this.myTargets = !this.myTargets;
            this.myAchivements = !this.myAchivements;
            this.myDaySummary = !this.myDaySummary;
            this.myExpense = !this.myExpense;
            this.myVisits = !this.myVisits;
            if(!this.isDropdownProOpen){
                this.toggleProductiveDropdown();
            }
        }
        else if(name === 'map'){
            this.myTargets = !this.myTargets;
            this.myAchivements = !this.myAchivements;
            this.myDaySummary = !this.myDaySummary;
            this.myProductivity = !this.myProductivity;
            this.myExpense = !this.myExpense;
            if(!this.isVisitDropdownOpen){
                this.toggleVisitDropdown();
            }
        }
        else if(name === 'Expense'){
            this.myTargets = !this.myTargets;
            this.myAchivements = !this.myAchivements;
            this.myDaySummary = !this.myDaySummary;
            this.myProductivity = !this.myProductivity;
            this.myVisits = !this.myVisits;
            if(!this.isDropdownExpenseOpen){
                this.toggleExpenseDropdown();
            }
        }
    }
}