package vn.gomate.semantic.service;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.*;
import org.springframework.stereotype.Service;
import vn.gomate.semantic.dto.SemanticDtos;
import vn.gomate.semantic.repository.SemanticRepository;

@Service
public class SemanticService {
 private final SemanticRepository repo;
 public SemanticService(SemanticRepository repo) { this.repo=repo; }

 public List<SemanticDtos.InterestOption> interests() {
  return repo.interests().stream().map(row -> new SemanticDtos.InterestOption(
   asLong(row.get("id")),
   (String)row.get("code"),
   (String)row.get("label"),
   (String)row.get("groupCode"),
   (String)row.get("groupName"),
   (String)row.get("interestType"),
   (String)row.get("description"),
   (Boolean)row.get("active")
  )).toList();
 }

 public List<SemanticDtos.PlaceTag> tags() {
  return repo.tags().stream().map(row -> new SemanticDtos.PlaceTag(
   asLong(row.get("id")),
   (String)row.get("code"),
   (String)row.get("label"),
   (Boolean)row.get("active")
  )).toList();
 }

 public List<SemanticDtos.InterestTagMapping> interestTagMappings() {
  return repo.interestTagMappings().stream().map(row -> new SemanticDtos.InterestTagMapping(
   (String)row.get("interestCode"),
   (String)row.get("tagCode"),
   (BigDecimal)row.get("weight")
  )).toList();
 }

 public List<SemanticDtos.PlaceTagLink> placeTags(long placeId) {
  return repo.placeTags(placeId).stream().map(row -> new SemanticDtos.PlaceTagLink(
   asLong(row.get("placeId")),
   (String)row.get("externalId"),
   (String)row.get("placeName"),
   (String)row.get("tagCode"),
   (String)row.get("tagLabel"),
   (BigDecimal)row.get("weight")
  )).toList();
 }

 public List<SemanticDtos.UserInterest> userInterests(UUID userId) {
  return repo.userInterests(userId).stream().map(row -> new SemanticDtos.UserInterest(
   (String)row.get("interestCode"),
   (String)row.get("interestLabel"),
   (String)row.get("groupCode"),
   (BigDecimal)row.get("preferenceWeight"),
   (LocalDateTime)row.get("selectedAt")
  )).toList();
 }

 private static Long asLong(Object value) {
  if(value==null) return null;
  if(value instanceof Number number) return number.longValue();
  return Long.valueOf(value.toString());
 }
}
