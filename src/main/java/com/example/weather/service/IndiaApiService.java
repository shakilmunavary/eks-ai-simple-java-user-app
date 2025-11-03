@Service
public class IndiaApiService {
    @Value("${indiaapi.baseurl}")
    private String baseUrl;

    @Value("${indiaapi.key}")
    private String apiKey;

    private final RestTemplate restTemplate = new RestTemplate();

    public List<String> getTamilNaduCities() {
        String url = baseUrl + "/states/Tamil Nadu/cities?apikey=" + apiKey;
        ResponseEntity<List<String>> response = restTemplate.exchange(
            url, HttpMethod.GET, null, new ParameterizedTypeReference<List<String>>() {});
        return response.getBody();
    }

    public WeatherData getWeatherForCity(String city) {
        String url = baseUrl + "/weather/" + city + "?apikey=" + apiKey;
        return restTemplate.getForObject(url, WeatherData.class);
    }
}
