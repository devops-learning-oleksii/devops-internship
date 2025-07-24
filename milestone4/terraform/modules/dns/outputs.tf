output "a_records" {
  value = {
    for name, rec in cloudflare_record.a : name => rec.id
  }
}
