var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sept", "Oct", "Nov", "Dec"];
var months2 = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

$("#seasonSlider").dateRangeSlider({
	bounds: {min: new Date(2012, 2, 1), max: new Date(2012, 9, 31, 12, 59, 59)},
	defaultValues: {min: new Date(2012, 5, 1), max: new Date(2012, 7, 31)},
	formatter: function(val) {
		var days = val.getDate(),
			month = val.getMonth();
			
		return months2[month] + " " + days;
	},
	scales: [{
		first: function(value){ return value; },
		end: function(value) {return value; },
		next: function(value){
			var next = new Date(value);
			return new Date(next.setMonth(value.getMonth() + 1));
		},
		label: function(value){
			return months[value.getMonth()];
		},
		format: function(tickContainer, tickStart, tickEnd){
			tickContainer.addClass("myCustomClass");
		}
	}]
});

var dateSliderBinding = new Shiny.InputBinding();
$.extend(dateSliderBinding, {
	find: function(scope) {
		return $(scope).find(".shiny-daterange-slider");
	},
	getValue: function(el) {
		return $(el).dateRangeSlider("values");
	},
	subscribe: function(el, callback) {
		$(el).on("valuesChanged", function(e) {
			callback();
		})
	},
	unsubscribe: function(e) {
		$(el).off("valuesChanged");
	}
});
Shiny.inputBindings.register(dateSliderBinding);

// MAP STUFF //

var bounds = L.latLngBounds([30, -89], [49, -70])
var states, sites, spaceGroup

function resizeMap() {
  document.getElementById("map").style.width = $("#map").parent().width() + "px";
  var h = Math.min(window.innerHeight, $("#map").parent().width());
  document.getElementById("map").style.height = h + "px"; 
  map.options.minZoom = 1;
  map.options.maxZoom = 15;
  map.fitBounds(bounds);
  map.options.minZoom = map.getZoom();
  map.options.maxZoom = map.getZoom();
  map.dragging.disable();
}

function setColor(layer) {
    
  var perc, 
      grad = ["#FF0000", "#FF3800", "#FF7100", "#FFAA00", "#FFE200", "#E2FF00", "#AAFF00", "#71FF00", "#38FF00", "#00FF00"]
    
  if(layer.hasOwnProperty("feature")) {
    perc = layer.feature.properties.percent;
  } else {
    perc = layer;
  }
    
  if(perc > -1) {
    var i = parseInt(perc/10, 10)
    if(i > 9) i = 9
    var c = grad[i];
  } else {
    var c = "#CCC";
  }

  return c;

}

var map = L.map("map", {zoomControl: false});

$(window).resize(function() {
  resizeMap();
})

$("#mapTab").on("shown.bs.tab", function(e) {
	resizeMap();
})

var basemap = L.layerGroup([L.esri.basemapLayer("Gray")])

basemap.addTo(map);

$.ajax({
  dataType: "json",
  url: "data/states.geojson",
  success: function(data) {
    states = L.geoJson(data, {style: {fillColor: '#CCC', weight: 1.5, opacity: 1, color: '#333', fillOpacity: 0.4}}).addTo(map);
  }
});

Shiny.addCustomMessageHandler("percentUpdate", function(data) {
  states.eachLayer(function(layer) {
    if(data !== undefined) {
      var sc = parseInt(layer.feature.properties.STATEFP, 10);
      var i = data.STATE_CODE.indexOf(sc);
      if(i > -1) {
        var perc = parseInt(data.EXCEED[i] / data.EXCEED_ALL[i] * 100, 10);
      } else {
        var perc = -1;
      }
      layer.feature.properties.percent = perc;
    }
    layer.setStyle({fillColor: setColor(layer)})
  })
})
// LEGEND //

var legend = L.control({position: 'bottomright'});

legend.onAdd = function(map) {
  
  var div = L.DomUtil.create('div', 'info legend'),
      grades = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90],
      labels = [];
  div.innerHTML = "<span class = 'legend-title'>Exceedences<br />Captured (%)</span><br />";    
  for(var i = 0; i < grades.length; i++) {
    div.innerHTML +=
        '<i style="background:' + setColor(grades[i]) + '"></i><span id = "legend_' + grades[i] + '">' +
        grades[i] + (grades[i + 1] ? '&ndash;' + grades[i + 1] + '</span><br>' : '+') ;
  }
  
  return div;
  
}

function colorLegend() {
  
  var sf = parseInt($("#scaleMod").val(), 10); 
  
  for(var i = 0; i < 100; i=i+10) {
    var g = parseInt(i / sf, 10);
    var h = parseInt((i + 10)/ sf, 10);
    var t;
    if(i == 90) {
      t = g + '&ndash;100'
    } else {
      t = g + '&ndash;' + h;
    }
    $("#legend_" + i).html(t);
    
  }
  
}

legend.addTo(map);

resizeMap();