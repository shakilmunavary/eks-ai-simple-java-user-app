@RestController
@RequestMapping("/weather")
public class WeatherController {
    @Autowired
    private IndiaApiService indiaApiService;

    @GetMapping("/cities")
    public List<String> getTamilNaduCities() {
        return indiaApiService.getTamilNaduCities();
    }

    @GetMapping("/{city}")
    public WeatherData getWeather(@PathVariable String city) {
        return indiaApiService.getWeatherForCity(city);
    }
}
